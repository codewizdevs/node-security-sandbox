#!/usr/bin/env node

console.log('🔍 Node.js Sandbox Quick Test');
console.log('============================');
console.log('Node version:', process.version);
console.log('Home directory:', require('os').homedir());
console.log('Current directory:', process.cwd());

// Test write to sandbox home
const fs = require('fs');
const path = require('path');
const testFile = path.join(require('os').homedir(), 'test-write.txt');

try {
    fs.writeFileSync(testFile, 'Sandbox test successful!');
    const content = fs.readFileSync(testFile, 'utf8');
    console.log('✅ Write test:', content);
    fs.unlinkSync(testFile);
} catch (error) {
    console.log('❌ Write test failed:', error.message);
}

// Test sensitive file access
try {
    const sensitiveFile = '/home/' + (process.env.USER || 'user') + '/.ssh/id_rsa';
    fs.readFileSync(sensitiveFile);
    console.log('❌ Security issue: Can read SSH keys!');
} catch (error) {
    console.log('✅ Security test: SSH keys protected');
}

// Test real home directory access
try {
    const realHome = '/home/' + (process.env.USER || 'user');
    const contents = fs.readdirSync(realHome);
    console.log('⚠️  Can access real home directory:', contents.slice(0, 3).join(', '));
} catch (error) {
    console.log('✅ Real home directory blocked');
}

console.log('\n🎯 Quick test complete!');
