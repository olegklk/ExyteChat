const io = require('socket.io-client');

const serverUrl = 'https://chat-back.gramatune.com';

// Auth data for socket connection
const authData = {
  chatType: "group",
  participants: ["u_98b2efd2", "u_98b2efd3"],
  userId: "u_98b2efd2"
};

// Variables to store server-assigned IDs
let assignedConversationId = null;
let assignedBatchId = null;

console.log('Connecting to Socket.IO server:', serverUrl);
console.log('Auth data:', authData);

// Create socket connection with auth data
const socket = io(serverUrl, {
  auth: authData,
  transports: ['websocket', 'polling']
});

// Handle connection events
socket.on('connect', () => {
  console.log('Connected to Socket.IO server');
  console.log('Socket ID:', socket.id);
  
  // Define payload for chat_append
  const payload = {
    conversationId: assignedConversationId || 'test_conversation_id',
    batchId: assignedBatchId || 'test_batch_id',
    text: 'Hello Socket.IO from client!',
    senderId: authData.userId,
    senderName: "User 113",
    timestamp: new Date().toISOString()
  };
    
//    {
//      "conversationId": "c:u_43d454f0",
//      "batchId": "2ca90b1a-fb08-4d74-bfe1-8492b50a66c1",
//      "messageId": "msg_id_0",
//      "text": "Test message",
//      "attachments": null,
//      "replyTo": null,
//      "expiresInMs": null,
//      "expiresAt": null,
//      "senderId": "u_98b2efd2",
//      "senderName": "User 113"
//    }

  // Send the message to chat_append channel
  console.log('Sending message to chat_append channel...');
  socket.emit('chat_append', payload);
  
  // Wait a bit and then disconnect
  setTimeout(() => {
    console.log('Disconnecting...');
    socket.disconnect();
    process.exit(0);
  }, 2000);
});

socket.on('connect_error', (error) => {
  console.error('Connection error:', error);
  process.exit(1);
});

socket.on('disconnect', (reason) => {
  console.log('Disconnected:', reason);
});

// Listen for any responses on chat_append or other channels
socket.onAny((eventName, data) => {
  console.log('Received event:', eventName, 'Data:', data);
});

// Handle process termination
process.on('SIGINT', () => {
  console.log('\nReceived SIGINT, disconnecting...');
  socket.disconnect();
  process.exit(0);
});
