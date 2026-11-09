import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { logger } from 'firebase-functions';
import { onDocumentUpdated } from 'firebase-functions/v2/firestore';

type Lang = 'uz' | 'ru' | 'en';

/** Localized push texts per status, in the user's chosen language. */
export const MESSAGES: Record<string, Record<Lang, { title: string; body: string }>> = {
  accepted: {
    uz: { title: 'Buyurtma qabul qilindi', body: 'Restoran buyurtmangizni qabul qildi' },
    ru: { title: 'Заказ принят', body: 'Ресторан принял ваш заказ' },
    en: { title: 'Order accepted', body: 'The restaurant accepted your order' },
  },
  cooking: {
    uz: { title: 'Tayyorlanmoqda', body: 'Buyurtmangiz tayyorlanmoqda' },
    ru: { title: 'Готовится', body: 'Ваш заказ готовится' },
    en: { title: 'Cooking', body: 'Your order is being prepared' },
  },
  on_the_way: {
    uz: { title: "Kuryer yo'lda", body: "Kuryer buyurtmangiz bilan yo'lga chiqdi" },
    ru: { title: 'Курьер в пути', body: 'Курьер уже везёт ваш заказ' },
    en: { title: 'Courier on the way', body: 'Your courier is on the way' },
  },
  delivered: {
    uz: { title: 'Yetkazildi', body: 'Yoqimli ishtaha!' },
    ru: { title: 'Доставлено', body: 'Приятного аппетита!' },
    en: { title: 'Delivered', body: 'Enjoy your meal!' },
  },
  cancelled: {
    uz: { title: 'Bekor qilindi', body: 'Buyurtmangiz bekor qilindi' },
    ru: { title: 'Отменён', body: 'Ваш заказ отменён' },
    en: { title: 'Cancelled', body: 'Your order was cancelled' },
  },
};

export function messageFor(status: string, language?: string) {
  const texts = MESSAGES[status];
  if (!texts) return null;
  const lang: Lang = language === 'ru' || language === 'en' ? language : 'uz';
  return texts[lang];
}

/** Sends a push when the order status changes. */
export const notifyOrderStatus = onDocumentUpdated(
  { document: 'orders/{orderId}', region: 'europe-west1' },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after || before.status === after.status) return;

    const userRef = getFirestore().collection('users').doc(after.userId);
    const user = (await userRef.get()).data();
    const token: string | undefined = user?.fcmToken;
    if (!token || user?.notificationsEnabled === false) return;

    const text = messageFor(after.status, user?.language);
    if (!text) return;

    try {
      await getMessaging().send({
        token,
        notification: text,
        // orderId lets the app open the order (deep link) on tap.
        data: { orderId: event.params.orderId, status: after.status, type: 'order_status' },
        android: {
          priority: 'high',
          notification: { channelId: 'order_status', icon: 'ic_notification' },
        },
        apns: { payload: { aps: { sound: 'default' } } },
      });
    } catch (e: unknown) {
      const code = (e as { code?: string }).code;
      if (code === 'messaging/registration-token-not-registered') {
        await userRef.update({ fcmToken: FieldValue.delete() });
      } else {
        logger.error('push failed', e);
      }
    }
  },
);
