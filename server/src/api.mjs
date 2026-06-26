import { requireAccountID } from "./auth.mjs";
import crypto from "node:crypto";
import { ValidationError } from "./app-store.mjs";
import { normalizeEvent } from "./events.mjs";
import { readJSONBody, sendJSON } from "./http.mjs";
import { createObjectStorageProvider } from "./object-storage.mjs";
import { renderShareCardOGSVG } from "./share-card-page.mjs";
import { normalizeIAPTransactionInput } from "./iap-products.mjs";
import { validateStoreKitSignedTransactionJWS } from "./storekit-jws.mjs";
import {
  accountIDFromAppStoreNotification,
  iapTransactionInputFromAppStoreNotification,
  shouldMaterializeSubscriptionFromNotification,
  validateAppStoreServerNotification
} from "./storekit-notifications.mjs";
import { createSMSProvider } from "./sms-provider.mjs";
import { createWeChatProvider } from "./wechat-provider.mjs";

export async function handleAPIRequest(req, res, appStore, now = () => new Date(), eventStore = null, objectStorageProvider = createObjectStorageProvider()) {
  const url = new URL(req.url, "http://localhost");

  if (req.method === "POST" && url.pathname === "/api/iap/app-store/notifications") {
    const body = await readJSONBody(req);
    const notification = validateAppStoreServerNotification(body);
    const linkedAccountID = accountIDFromAppStoreNotification(notification);
    let subscriptionResult = null;

    await appendServerEvent(eventStore, "app_store_server_notification_received", {
      notification_type: notification.notification_type,
      subtype: notification.subtype ?? "none",
      notification_uuid: notification.notification_uuid,
      bundle_id: notification.bundle_id ?? "unknown",
      environment: notification.environment ?? "unknown",
      product_id: notification.transaction_payload?.productId ?? "unknown",
      account_linked: linkedAccountID ? "true" : "false",
      "$lib": "server"
    }, linkedAccountID ?? notification.notification_uuid, now());

    if (linkedAccountID && shouldMaterializeSubscriptionFromNotification(notification)) {
      const transactionInput = iapTransactionInputFromAppStoreNotification(notification);
      if (transactionInput) {
        const verifiedInput = normalizeIAPTransactionInput(transactionInput);
        validateStoreKitSignedTransactionJWS(verifiedInput);
        subscriptionResult = await appStore.verifyIAPTransaction(linkedAccountID, verifiedInput, now());
        if (subscriptionResult.created) {
          await appendServerEvent(eventStore, "subscription_created", {
            user_id: linkedAccountID,
            plan: subscriptionResult.subscription.plan,
            amount: subscriptionResult.subscription.amount,
            currency: subscriptionResult.subscription.currency,
            transaction_id: subscriptionResult.subscription.transaction_id,
            product_id: subscriptionResult.subscription.product_id,
            payment_provider: "storekit",
            source: "app_store_server_notification",
            notification_type: notification.notification_type,
            notification_uuid: notification.notification_uuid,
            environment: subscriptionResult.subscription.environment,
            "$lib": "server"
          }, linkedAccountID, now());
        }
      }
    }

    return sendJSON(res, 200, {
      ok: true,
      notification: {
        notification_type: notification.notification_type,
        subtype: notification.subtype,
        notification_uuid: notification.notification_uuid,
        environment: notification.environment,
        account_linked: Boolean(linkedAccountID)
      },
      subscription: subscriptionResult?.subscription ?? null,
      subscription_created: subscriptionResult?.created ?? false
    });
  }

  const accountID = requireAccountID(req);

  if (req.method === "POST" && url.pathname === "/api/accounts/upgrade") {
    const body = await readJSONBody(req);
    const result = await appStore.upgradeAccount(accountID, body, now());
    return sendJSON(res, 200, { ok: true, ...result });
  }

  if (req.method === "POST" && url.pathname === "/api/accounts/delete") {
    const body = await readJSONBody(req);
    const result = await appStore.deleteAccount(accountID, body, now());
    return sendJSON(res, 200, { ok: true, ...result });
  }

  if (req.method === "POST" && url.pathname === "/api/auth/sms/send") {
    const body = await readJSONBody(req);
    const delivery = await createSMSProvider().sendVerificationCode(body);
    const challenge = await appStore.createSMSChallenge(accountID, body, now(), delivery.code);
    return sendJSON(res, 201, {
      ok: true,
      sms_challenge: challenge,
      delivery: {
        provider: delivery.provider,
        status: delivery.delivery_status
      }
    });
  }

  if (req.method === "POST" && url.pathname === "/api/auth/sms/verify") {
    const body = await readJSONBody(req);
    const result = await appStore.verifySMSChallenge(accountID, body, now());
    return sendJSON(res, 200, { ok: true, sms_challenge: result });
  }

  if (req.method === "POST" && url.pathname === "/api/auth/wechat/exchange") {
    const body = await readJSONBody(req);
    const identity = await createWeChatProvider().exchangeAuthorizationCode(body);
    const result = await appStore.upgradeAccount(accountID, {
      method: "wechat",
      provider_user_hash: identity.provider_user_hash,
      wechat_open_id_hash: identity.wechat_open_id_hash
    }, now());
    return sendJSON(res, 200, {
      ok: true,
      provider: identity.provider,
      scope: identity.scope,
      ...result
    });
  }

  if (req.method === "POST" && url.pathname === "/api/iap/transactions/verify") {
    const body = await readJSONBody(req);
    const verifiedInput = normalizeIAPTransactionInput(body);
    validateStoreKitSignedTransactionJWS(verifiedInput);
    const result = await appStore.verifyIAPTransaction(accountID, verifiedInput, now());
    if (result.created) {
      await appendServerEvent(eventStore, "subscription_created", {
        user_id: accountID,
        plan: result.subscription.plan,
        amount: result.subscription.amount,
        currency: result.subscription.currency,
        transaction_id: result.subscription.transaction_id,
        product_id: result.subscription.product_id,
        payment_provider: "storekit",
        environment: result.subscription.environment,
        ...(typeof verifiedInput.smoke_run_id === "string" && verifiedInput.smoke_run_id.trim()
          ? { smoke_run_id: verifiedInput.smoke_run_id.trim() }
          : {}),
        "$lib": "server"
      }, accountID, now());
    }
    return sendJSON(res, 200, { ok: true, ...result });
  }

  if (req.method === "POST" && url.pathname === "/api/share-cards/render") {
    const body = await readJSONBody(req);
    const postID = requiredBodyString(body.post_id, "post_id");
    appStore.getOwnPost(accountID, postID);
    const card = await appStore.getPublicShareCard(postID);
    const svg = renderShareCardOGSVG(card);
    const upload = await objectStorageProvider.putObject({
      key: `cloud-cards/${postID}.svg`,
      body: svg,
      contentType: "image/svg+xml",
      isPublic: true
    });
    return sendJSON(res, 201, {
      ok: true,
      share_card: {
        post_id: postID,
        template_id: card.template_id,
        object_key: upload.object_key,
        share_image_url: upload.public_url,
        content_type: "image/svg+xml",
        channel: stringOrNull(body.channel)
      }
    });
  }

  if (req.method === "POST" && url.pathname === "/api/flight-contexts/create") {
    const body = await readJSONBody(req);
    const context = await appStore.createFlightContext(accountID, body, now());
    return sendJSON(res, 201, { ok: true, flight_context: context });
  }

  if (req.method === "POST" && url.pathname === "/api/flight-proof/create") {
    const body = await readJSONBody(req);
    const proof = await appStore.createFlightProof(accountID, body, now());
    return sendJSON(res, 201, { ok: true, flight_proof: proof });
  }

  if (req.method === "POST" && url.pathname === "/api/posts/create") {
    const body = await readJSONBody(req);
    const post = await appStore.createPost(accountID, body, now());
    return sendJSON(res, 201, { ok: true, post });
  }

  const postMatch = url.pathname.match(/^\/api\/posts\/([^/]+)$/);
  if (postMatch && req.method === "GET") {
    const post = await appStore.getOwnPost(accountID, postMatch[1]);
    return sendJSON(res, 200, { ok: true, post });
  }

  if (postMatch && req.method === "PATCH") {
    const body = await readJSONBody(req);
    const post = await appStore.updateOwnPost(accountID, postMatch[1], body);
    return sendJSON(res, 200, { ok: true, post });
  }

  if (postMatch && req.method === "DELETE") {
    await appStore.deleteOwnPost(accountID, postMatch[1]);
    return sendJSON(res, 200, { ok: true });
  }

  const flightSpaceMatch = url.pathname.match(/^\/api\/flight-spaces\/([^/]+)\/posts$/);
  if (flightSpaceMatch && req.method === "GET") {
    const posts = await appStore.listSameFlightPosts(accountID, flightSpaceMatch[1]);
    return sendJSON(res, 200, { ok: true, posts });
  }

  if (req.method === "POST" && url.pathname === "/api/comments/create") {
    const body = await readJSONBody(req);
    const comment = await appStore.createComment(accountID, body, now());
    return sendJSON(res, 201, { ok: true, comment });
  }

  if (req.method === "POST" && url.pathname === "/api/reports/create") {
    const body = await readJSONBody(req);
    const report = await appStore.createReport(accountID, body, now());
    return sendJSON(res, 201, { ok: true, report });
  }

  if (req.method === "POST" && url.pathname === "/api/blocks/create") {
    const body = await readJSONBody(req);
    const block = await appStore.createBlock(accountID, body, now());
    return sendJSON(res, 201, { ok: true, block });
  }

  if (req.method === "POST" && url.pathname === "/api/push-tokens/register") {
    const body = await readJSONBody(req);
    const pushToken = await appStore.registerPushToken(accountID, body, now());
    return sendJSON(res, 201, { ok: true, push_token: pushToken });
  }

  if (req.method === "POST" && url.pathname === "/api/notification-jobs/boarding-reminder/create") {
    const body = await readJSONBody(req);
    const job = await appStore.createBoardingReminderJob(accountID, body, now());
    return sendJSON(res, 201, { ok: true, notification_job: job });
  }

  return false;
}

async function appendServerEvent(eventStore, eventName, properties, accountID, timestamp) {
  if (!eventStore || typeof eventStore.append !== "function") {
    return;
  }
  await eventStore.append(normalizeEvent({
    event_name: eventName,
    properties,
    app_version: "server",
    platform: "server",
    user_id_hash: stableHash(accountID),
    client_time: timestamp.toISOString()
  }, timestamp));
}

function stableHash(value) {
  return crypto.createHash("sha256").update(String(value).trim().toUpperCase()).digest("hex");
}

function requiredBodyString(value, fieldName) {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new ValidationError(`${fieldName} is required`);
  }
  return value.trim();
}

function stringOrNull(value) {
  if (typeof value !== "string") {
    return null;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}
