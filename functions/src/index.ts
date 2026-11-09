import { initializeApp } from 'firebase-admin/app';

initializeApp();

export { api } from './api';
export { simulateCourier } from './simulator';
export { notifyOrderStatus } from './notifications';
