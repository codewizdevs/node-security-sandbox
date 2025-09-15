#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const os = require('os');

console.log('🔍 Node.js Sandbox Comprehensive Test');
console.log('=====================================');
console.log('Node version:', process.version);
console.log('Sandbox home directory:', os.homedir());
console.log('Current directory:', process.cwd());
console.log('User:', process.env.USER || 'unknown');
console.log('');

// Helper function to safely list directory contents
function listDirectory(dirPath, maxFiles = 20) {
    try {
        const contents = fs.readdirSync(dirPath);
        const files = contents.slice(0, maxFiles);
        const total = contents.length;
        
        console.log(`📁 ${dirPath} (${total} total items, showing first ${files.length}):`);
        if (files.length > 0) {
            files.forEach((file, index) => {
                const fullPath = path.join(dirPath, file);
                try {
                    const stats = fs.statSync(fullPath);
                    const type = stats.isDirectory() ? '📁' : '📄';
                    const size = stats.isFile() ? ` (${stats.size} bytes)` : '';
                    console.log(`  ${index + 1}. ${type} ${file}${size}`);
                } catch (statError) {
                    console.log(`  ${index + 1}. ❓ ${file} (cannot stat)`);
                }
            });
            if (total > maxFiles) {
                console.log(`  ... and ${total - maxFiles} more items`);
            }
        } else {
            console.log('  (empty directory)');
        }
        console.log('');
        return true;
    } catch (error) {
        console.log(`❌ Cannot access ${dirPath}: ${error.message}`);
        console.log('');
        return false;
    }
}

// Test write to sandbox home
console.log('🧪 Testing write permissions in sandbox home...');
const testFile = path.join(os.homedir(), 'test-write.txt');
try {
    fs.writeFileSync(testFile, 'Sandbox test successful!');
    const content = fs.readFileSync(testFile, 'utf8');
    console.log('✅ Write test successful:', content);
    fs.unlinkSync(testFile);
} catch (error) {
    console.log('❌ Write test failed:', error.message);
}
console.log('');

// Test sensitive file access
console.log('🔒 Testing sensitive file access...');
const sensitiveFiles = [
    '/home/' + (process.env.USER || 'user') + '/.ssh/id_rsa',
    '/home/' + (process.env.USER || 'user') + '/.ssh/id_ed25519',
    '/home/' + (process.env.USER || 'user') + '/.bashrc',
    '/home/' + (process.env.USER || 'user') + '/.profile',
    '/home/' + (process.env.USER || 'user') + '/.gitconfig'
];

sensitiveFiles.forEach(file => {
    try {
        fs.readFileSync(file);
        console.log(`❌ Security issue: Can read ${file}`);
    } catch (error) {
        console.log(`✅ Protected: ${path.basename(file)}`);
    }
});
console.log('');

// Test real home directory access
console.log('🏠 Testing real home directory access...');
const realHome = '/home/' + (process.env.USER || 'user');
listDirectory(realHome, 20);

// Test desktop directory access
console.log('🖥️  Testing desktop directory access...');
const desktopPath = path.join(realHome, 'Desktop');
listDirectory(desktopPath, 20);

// Test Documents directory access
console.log('📄 Testing documents directory access...');
const documentsPath = path.join(realHome, 'Documents');
listDirectory(documentsPath, 20);

// Test Downloads directory access
console.log('⬇️  Testing downloads directory access...');
const downloadsPath = path.join(realHome, 'Downloads');
listDirectory(downloadsPath, 20);

// Test .config directory access
console.log('⚙️  Testing .config directory access...');
const configPath = path.join(realHome, '.config');
listDirectory(configPath, 20);

// Test system directories
console.log('🖥️  Testing system directory access...');
const systemDirs = ['/etc', '/var', '/tmp', '/root'];
systemDirs.forEach(dir => {
    try {
        const contents = fs.readdirSync(dir);
        console.log(`❌ Can access ${dir} (${contents.length} items)`);
    } catch (error) {
        console.log(`✅ Protected: ${dir}`);
    }
});
console.log('');

// Test current working directory
console.log('📂 Current working directory contents:');
listDirectory(process.cwd(), 20);

// Test sandbox home directory
console.log('🏠 Sandbox home directory contents:');
listDirectory(os.homedir(), 20);

// Network test
console.log('🌐 Testing network access...');
try {
    const https = require('https');
    const req = https.get('https://registry.npmjs.org', (res) => {
        console.log(`✅ Network access: npm registry (status: ${res.statusCode})`);
    });
    req.on('error', (error) => {
        console.log(`❌ Network access failed: ${error.message}`);
    });
    req.setTimeout(5000, () => {
        req.destroy();
        console.log('⏰ Network test timeout');
    });
} catch (error) {
    console.log(`❌ Network test error: ${error.message}`);
}

console.log('\n🎯 Comprehensive test complete!');
console.log('=====================================');
console.log('Summary:');
console.log('- If you see "Protected" or "Cannot access" messages, the sandbox is working correctly');
console.log('- If you see file listings, those directories are accessible to the sandbox');
console.log('- The sandbox should only allow access to the current directory and sandbox home');
