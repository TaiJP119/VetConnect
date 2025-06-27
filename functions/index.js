const fcmFunctions = require("./fcmFunctions");
const eventReminderFunctions = require("./eventReminderFunctions");

// ✅ Correct way to merge exports for Firebase Functions
Object.assign(exports, fcmFunctions, eventReminderFunctions);
