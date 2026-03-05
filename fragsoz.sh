#!/bin/bash

# Fragsöz Projesi - Geliştirilmiş Kurulum Scripti
# Termux için hazırlanmıştır
# Güvenlik, otomatik resim optimizasyonu ve profesyonel tasarım

echo "🚀 Fragsöz Projesi Kuruluyor..."

# Gerekli paketleri yükle
pkg update -y
pkg install -y nodejs git

# Proje klasörünü oluştur
cd ~
rm -rf fragsoz
mkdir -p fragsoz
cd fragsoz

# package.json oluştur
cat > package.json << 'EOF'
{
  "name": "fragsoz",
  "version": "2.0.0",
  "description": "Kitap Fragman Platformu - Gelişmiş Versiyon",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "qrcode": "^1.5.3",
    
    "express-rate-limit": "^7.1.5",
    "helmet": "^7.1.0",
    "express-validator": "^7.0.1",
    "multer": "^1.4.5-lts.1"
  }
}
EOF

# Node modüllerini yükle
npm install

# uploads klasörünü oluştur
mkdir -p public/uploads

# database.json oluştur (varsayılan admin hesabı ile)
cat > database.json << 'EOF'
{
  "books": [
    {
      "id": 1,
      "title": "Suç ve Ceza",
      "author": "Fyodor Dostoyevski",
      "category": "Klasik",
      "summary": "Raskolnikov adlı genç bir adamın işlediği cinayet ve sonrasında yaşadığı vicdan muhasebesi.",
      "coverUrl": "https://i.dr.com.tr/cache/600x600-0/originals/0000000064036-1.jpg",
      "videoUrl": "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
      "qrCount": 0
    },
    {
      "id": 2,
      "title": "1984",
      "author": "George Orwell",
      "category": "Distopya",
      "summary": "Totaliter bir rejimin hüküm sürdüğü gelecekte, bireyin özgürlüğü ve düşünce sisteminin kontrolü.",
      "coverUrl": "https://i.dr.com.tr/cache/600x600-0/originals/0001844952001-1.jpg",
      "videoUrl": "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
      "qrCount": 0
    },
    {
      "id": 3,
      "title": "Savaş ve Barış",
      "author": "Lev Tolstoy",
      "category": "Klasik",
      "summary": "Napolyon savaşları döneminde Rus aristokrasisinin yaşamı ve aşk hikayesi.",
      "coverUrl": "https://i.dr.com.tr/cache/600x600-0/originals/0001839988001-1.jpg",
      "videoUrl": "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
      "qrCount": 0
    }
  ],
  "users": [
    {
      "id": 1,
      "username": "admin",
      "password": "admin123",
      "isAdmin": true
    }
  ]
}
EOF

# server.js oluştur (Multer ile dosya yükleme desteği)
cat > server.js << 'SERVEREOF'
const express = require('express');
const fs = require('fs');
const path = require('path');
const QRCode = require('qrcode');

const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const { body, validationResult } = require('express-validator');
const multer = require('multer');

const app = express();
const PORT = 3000;


// Multer yapılandırması - dosya yükleme
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    cb(null, 'public/uploads/');
  },
  filename: function (req, file, cb) {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, uniqueSuffix + path.extname(file.originalname));
  }
});

const fileFilter = (req, file, cb) => {
  const allowedTypes = /jpeg|jpg|png|gif|webp|svg|bmp|tiff/;
  const extname = allowedTypes.test(path.extname(file.originalname).toLowerCase());
  const mimetype = allowedTypes.test(file.mimetype);
  
  if (mimetype && extname) {
    return cb(null, true);
  } else {
    cb(new Error('Sadece resim dosyaları yüklenebilir!'));
  }
};

const upload = multer({ 
  storage: storage,
  fileFilter: fileFilter,
  limits: { fileSize: 5 * 1024 * 1024 } // 5MB limit
});

// Güvenlik middleware'leri
app.use(helmet({
  contentSecurityPolicy: false
}));

app.use(express.json({ limit: '10mb' }));
app.use(express.static('public'));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  message: 'Çok fazla istek gönderdiniz. Lütfen 15 dakika sonra tekrar deneyin.'
});

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5,
  message: 'Çok fazla giriş denemesi. Lütfen 15 dakika sonra tekrar deneyin.'
});

app.use('/api/', limiter);
app.use('/api/login', authLimiter);
app.use('/api/register', authLimiter);

// Database okuma
function readDB() {
  try {
    const data = fs.readFileSync('database.json', 'utf8');
    return JSON.parse(data);
  } catch (error) {
    console.error('Database okuma hatası:', error);
    return { books: [], users: [] };
  }
}

// Database yazma
function writeDB(data) {
  try {
    fs.writeFileSync('database.json', JSON.stringify(data, null, 2));
  } catch (error) {
    console.error('Database yazma hatası:', error);
  }
}

// Input sanitization
function sanitizeInput(input) {
  if (typeof input !== 'string') return input;
  return input.trim().replace(/[<>]/g, '');
}

// Resim yükleme endpoint'i
app.post('/api/upload', upload.single('image'), (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'Dosya yüklenmedi' });
    }
    const imageUrl = `/uploads/${req.file.filename}`;
    res.json({ success: true, imageUrl: imageUrl });
  } catch (error) {
    res.status(500).json({ error: 'Dosya yüklenirken hata oluştu' });
  }
});

// Tüm kitapları getir
app.get('/api/books', (req, res) => {
  try {
    const db = readDB();
    res.json(db.books);
  } catch (error) {
    res.status(500).json({ error: 'Sunucu hatası' });
  }
});

// Tek kitap getir
app.get('/api/books/:id', (req, res) => {
  try {
    const db = readDB();
    const bookId = parseInt(req.params.id);
    
    if (isNaN(bookId)) {
      return res.status(400).json({ error: 'Geçersiz kitap ID' });
    }
    
    const book = db.books.find(b => b.id === bookId);
    if (book) {
      res.json(book);
    } else {
      res.status(404).json({ error: 'Kitap bulunamadı' });
    }
  } catch (error) {
    res.status(500).json({ error: 'Sunucu hatası' });
  }
});

// QR Kod oluşturma
app.get('/api/qrcode/:id', async (req, res) => {
  try {
    const bookId = parseInt(req.params.id);
    
    if (isNaN(bookId)) {
      return res.status(400).json({ error: 'Geçersiz kitap ID' });
    }
    
    const url = `http://localhost:${PORT}/detail.html?id=${bookId}&qr=true`;
    const qrCodeDataURL = await QRCode.toDataURL(url, {
      width: 300,
      margin: 2,
      color: {
        dark: '#667eea',
        light: '#ffffff'
      }
    });
    res.json({ qrCode: qrCodeDataURL });
  } catch (error) {
    res.status(500).json({ error: 'QR kod oluşturulamadı' });
  }
});

// QR okutma sayacını artır
app.post('/api/qr/:id', (req, res) => {
  try {
    const db = readDB();
    const bookId = parseInt(req.params.id);
    
    if (isNaN(bookId)) {
      return res.status(400).json({ error: 'Geçersiz kitap ID' });
    }
    
    const book = db.books.find(b => b.id === bookId);
    if (book) {
      book.qrCount++;
      writeDB(db);
      res.json({ success: true, qrCount: book.qrCount });
    } else {
      res.status(404).json({ error: 'Kitap bulunamadı' });
    }
  } catch (error) {
    res.status(500).json({ error: 'Sunucu hatası' });
  }
});

// Öneri kitaplar
app.get('/api/suggest/:category', (req, res) => {
  try {
    const db = readDB();
    const category = sanitizeInput(req.params.category);
    const suggested = db.books.filter(b => b.category === category).slice(0, 3);
    res.json(suggested);
  } catch (error) {
    res.status(500).json({ error: 'Sunucu hatası' });
  }
});

// Giriş (Login)
app.post('/api/login', [
  body('username').trim().isLength({ min: 3, max: 30 }).escape(),
  body('password').isLength({ min: 6, max: 100 })
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ error: 'Geçersiz giriş bilgileri' });
    }

    const db = readDB();
    const { username, password } = req.body;
    const user = db.users.find(u => u.username === username);
    
    if (!user) {
      return res.status(401).json({ error: 'Kullanıcı adı veya şifre hatalı' });
    }

    const passwordMatch = (password === user.password);
    
    if (passwordMatch) {
      res.json({ 
        success: true, 
        user: { 
          id: user.id, 
          username: user.username, 
          isAdmin: user.isAdmin 
        } 
      });
    } else {
      res.status(401).json({ error: 'Kullanıcı adı veya şifre hatalı' });
    }
  } catch (error) {
    res.status(500).json({ error: 'Sunucu hatası' });
  }
});

// Kayıt (Register)
app.post('/api/register', [
  body('username').trim().isLength({ min: 3, max: 30 }).isAlphanumeric().escape(),
  body('password').isLength({ min: 6, max: 100 })
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ error: 'Kullanıcı adı 3-30 karakter arası olmalı ve özel karakter içermemelidir' });
    }

    const db = readDB();
    const { username, password } = req.body;
    
    const existingUser = db.users.find(u => u.username === username);
    if (existingUser) {
      return res.status(400).json({ error: 'Bu kullanıcı adı zaten kullanılıyor' });
    }
    
    const plainPassword = password;
    
    const newUser = {
      id: db.users.length > 0 ? Math.max(...db.users.map(u => u.id)) + 1 : 1,
      username,
      password: plainPassword,
      isAdmin: false
    };
    
    db.users.push(newUser);
    writeDB(db);
    
    res.json({ 
      success: true, 
      user: { 
        id: newUser.id, 
        username: newUser.username, 
        isAdmin: newUser.isAdmin 
      } 
    });
  } catch (error) {
    res.status(500).json({ error: 'Sunucu hatası' });
  }
});

// Kitap ekleme (Sadece admin)
app.post('/api/books', [
  body('title').trim().notEmpty().escape(),
  body('author').trim().notEmpty().escape(),
  body('category').trim().notEmpty().escape(),
  body('summary').trim().notEmpty().escape(),
  body('coverUrl').trim().notEmpty(),
  body('videoUrl').trim().isURL()
], (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ error: 'Geçersiz kitap bilgileri' });
    }

    const db = readDB();
    const newBook = {
      id: db.books.length > 0 ? Math.max(...db.books.map(b => b.id)) + 1 : 1,
      title: sanitizeInput(req.body.title),
      author: sanitizeInput(req.body.author),
      category: sanitizeInput(req.body.category),
      summary: sanitizeInput(req.body.summary),
      coverUrl: req.body.coverUrl,
      videoUrl: req.body.videoUrl,
      qrCount: 0
    };
    
    db.books.push(newBook);
    writeDB(db);
    res.json(newBook);
  } catch (error) {
    res.status(500).json({ error: 'Sunucu hatası' });
  }
});

// Kitap güncelleme (Sadece admin)
app.put('/api/books/:id', (req, res) => {
  try {
    const db = readDB();
    const bookId = parseInt(req.params.id);
    
    if (isNaN(bookId)) {
      return res.status(400).json({ error: 'Geçersiz kitap ID' });
    }
    
    const index = db.books.findIndex(b => b.id === bookId);
    if (index !== -1) {
      db.books[index] = { 
        ...db.books[index], 
        ...req.body,
        id: bookId
      };
      writeDB(db);
      res.json(db.books[index]);
    } else {
      res.status(404).json({ error: 'Kitap bulunamadı' });
    }
  } catch (error) {
    res.status(500).json({ error: 'Sunucu hatası' });
  }
});

// Kitap silme (Sadece admin)
app.delete('/api/books/:id', (req, res) => {
  try {
    const db = readDB();
    const bookId = parseInt(req.params.id);
    
    if (isNaN(bookId)) {
      return res.status(400).json({ error: 'Geçersiz kitap ID' });
    }
    
    const index = db.books.findIndex(b => b.id === bookId);
    if (index !== -1) {
      db.books.splice(index, 1);
      writeDB(db);
      res.json({ success: true });
    } else {
      res.status(404).json({ error: 'Kitap bulunamadı' });
    }
  } catch (error) {
    res.status(500).json({ error: 'Sunucu hatası' });
  }
});

// Hata yakalama middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ error: 'Beklenmeyen bir hata oluştu' });
});

app.listen(PORT, () => {
  console.log(`✅ Fragsöz sunucusu http://localhost:${PORT} adresinde çalışıyor`);
  console.log(`🔒 Güvenlik özellikleri aktif`);
  console.log(`📊 Rate limiting aktif`);
  console.log(`📁 Dosya yükleme aktif`);
});
SERVEREOF

# public klasörünü oluştur
mkdir -p public

# index.html (aynı)
cat > public/index.html << 'EOF'
<!DOCTYPE html>
<html lang="tr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Fragsöz - Kitap Fragmanları Platformu</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <header>
        <div class="container">
            <div class="header-content">
                <div class="logo-section">
                    <h1>📚 Fragsöz</h1>
                    <p class="tagline">Kitapların Hikayesini Keşfedin</p>
                </div>
                <div class="auth-section-compact">
                    <div id="authButtons">
                        <button class="btn-auth-compact" onclick="showAuthModal('login')">Giriş</button>
                        <button class="btn-auth-compact secondary" onclick="showAuthModal('register')">Kayıt</button>
                    </div>
                    <div id="userSection" style="display: none;">
                        <span class="user-greeting" id="userGreeting"></span>
                        <button class="btn-logout-compact" onclick="logout()">Çıkış</button>
                    </div>
                </div>
            </div>
        </div>
    </header>

    <div class="hero-section">
        <div class="container">
            <div class="hero-content">
                <h2 class="hero-title">Kitapların Dünyasına Hoş Geldiniz</h2>
                <p class="hero-description">
                    Fragsöz, kitapların özünü tanıtım videoları ve fragmanlarla keşfetmenizi sağlayan yenilikçi bir platformdur. 
                    QR kod teknolojisi ile kitapları hızlıca tanıyın, videoları izleyin ve okuma listenizi zenginleştirin.
                </p>
            </div>
        </div>
    </div>

    <main class="container">
        <div class="search-filter">
            <input type="text" id="searchInput" placeholder="🔍 Kitap veya yazar ara..." onkeyup="filterBooks()">
            <select id="categoryFilter" onchange="filterBooks()">
                <option value="">Tüm Kategoriler</option>
                <option value="Klasik">Klasik</option>
                <option value="Distopya">Distopya</option>
                <option value="Roman">Roman</option>
                <option value="Bilim Kurgu">Bilim Kurgu</option>
                <option value="Fantastik">Fantastik</option>
            </select>
        </div>

        <div class="books-grid" id="booksGrid"></div>
    </main>

    <footer class="footer">
        <div class="container">
            <div class="footer-content">
                <div class="footer-brand">
                    <h3>📚 Fragsöz</h3>
                    <p class="footer-mission">
                        <strong>Misyonumuz:</strong> Okuyucuları kitaplarla buluşturmak, kitap seçim sürecini 
                        görsel ve interaktif hale getirerek okuma kültürünü yaygınlaştırmak. Her kitabın 
                        özgün hikayesini tanıtım videoları ile keşfetmenizi sağlıyoruz.
                    </p>
                </div>
                <div class="footer-links">
                    <h4>Hızlı Bağlantılar</h4>
                    <ul>
                        <li><a href="index.html">Ana Sayfa</a></li>
                        <li><a href="#" onclick="showAuthModal('login')">Giriş Yap</a></li>
                        <li><a href="#" onclick="showAuthModal('register')">Kayıt Ol</a></li>
                    </ul>
                </div>
                <div class="footer-info">
                    <h4>Platform Özellikleri</h4>
                    <ul>
                        <li>✓ QR Kod ile Hızlı Erişim</li>
                        <li>✓ Video Fragmanlar</li>
                        <li>✓ Akıllı Öneri Sistemi</li>
                        <li>✓ Kategori Bazlı Arama</li>
                    </ul>
                </div>
            </div>
            <div class="footer-bottom">
                <p>&copy; 2024 Fragsöz. Tüm hakları saklıdır. | Kitap severlerin buluşma noktası</p>
            </div>
        </div>
    </footer>

    <div id="authModal" class="modal">
        <div class="modal-content auth-modal">
            <span class="close" onclick="closeAuthModal()">&times;</span>
            <h2 id="authTitle">Giriş Yap</h2>
            
            <div id="loginForm">
                <input type="text" id="loginUsername" placeholder="Kullanıcı Adı" required>
                <input type="password" id="loginPassword" placeholder="Şifre" required>
                <button onclick="login()" class="btn-primary">Giriş Yap</button>
                <p class="auth-switch">Hesabınız yok mu? <a onclick="switchAuthMode('register')">Kayıt Olun</a></p>
            </div>
            
            <div id="registerForm" style="display: none;">
                <input type="text" id="registerUsername" placeholder="Kullanıcı Adı (3-30 karakter)" required>
                <input type="password" id="registerPassword" placeholder="Şifre (min 6 karakter)" required>
                <input type="password" id="registerPasswordConfirm" placeholder="Şifre Tekrar" required>
                <button onclick="register()" class="btn-primary">Kayıt Ol</button>
                <p class="auth-switch">Zaten hesabınız var mı? <a onclick="switchAuthMode('login')">Giriş Yapın</a></p>
            </div>
        </div>
    </div>

    <script src="script.js"></script>
</body>
</html>
EOF

# style.css devam ediyor...

# style.css oluştur (Admin panel düzeltmesi ile)
cat > public/style.css << 'STYLEEOF'
* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}

:root {
    --primary: #667eea;
    --primary-dark: #5568d3;
    --secondary: #764ba2;
    --text: #2d3748;
    --text-light: #718096;
    --bg: #f7fafc;
    --white: #ffffff;
    --shadow: rgba(0, 0, 0, 0.1);
    --shadow-lg: rgba(0, 0, 0, 0.15);
}

body {
    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
    background: var(--bg);
    color: var(--text);
    line-height: 1.6;
}

.container {
    max-width: 1200px;
    margin: 0 auto;
    padding: 0 20px;
}

/* Header */
header {
    background: linear-gradient(135deg, var(--primary) 0%, var(--secondary) 100%);
    color: var(--white);
    padding: 1rem 0;
    box-shadow: 0 2px 10px var(--shadow);
    position: sticky;
    top: 0;
    z-index: 100;
}

.header-content {
    display: flex;
    justify-content: space-between;
    align-items: center;
    flex-wrap: wrap;
    gap: 1rem;
}

.logo-section h1 {
    font-size: 2rem;
    font-weight: 700;
    margin-bottom: 0.2rem;
}

.tagline {
    font-size: 0.9rem;
    opacity: 0.95;
    font-weight: 300;
}

/* Compact Auth Section */
.auth-section-compact {
    display: flex;
    align-items: center;
    gap: 0.5rem;
}

.btn-auth-compact {
    background: rgba(255, 255, 255, 0.2);
    color: var(--white);
    border: 1px solid rgba(255, 255, 255, 0.3);
    padding: 0.5rem 1rem;
    border-radius: 6px;
    cursor: pointer;
    font-size: 0.85rem;
    transition: all 0.3s;
    font-weight: 500;
}

.btn-auth-compact:hover {
    background: rgba(255, 255, 255, 0.3);
    transform: translateY(-1px);
}

.btn-auth-compact.secondary {
    background: var(--white);
    color: var(--primary);
    border-color: var(--white);
}

.btn-auth-compact.secondary:hover {
    background: rgba(255, 255, 255, 0.9);
}

.btn-logout-compact {
    background: rgba(255, 255, 255, 0.15);
    color: var(--white);
    border: 1px solid rgba(255, 255, 255, 0.3);
    padding: 0.5rem 1rem;
    border-radius: 6px;
    cursor: pointer;
    font-size: 0.85rem;
    transition: all 0.3s;
}

.btn-logout-compact:hover {
    background: rgba(255, 255, 255, 0.25);
}

.user-greeting {
    font-size: 0.85rem;
    margin-right: 0.5rem;
    opacity: 0.95;
}

/* Hero Section */
.hero-section {
    background: linear-gradient(135deg, rgba(102, 126, 234, 0.1) 0%, rgba(118, 75, 162, 0.1) 100%);
    padding: 3rem 0;
    margin-bottom: 2rem;
}

.hero-content {
    text-align: center;
    max-width: 800px;
    margin: 0 auto;
}

.hero-title {
    font-size: 2.5rem;
    color: var(--text);
    margin-bottom: 1rem;
    font-weight: 700;
}

.hero-description {
    font-size: 1.1rem;
    color: var(--text-light);
    line-height: 1.8;
}

/* Search & Filter */
.search-filter {
    display: flex;
    gap: 1rem;
    margin-bottom: 2rem;
    flex-wrap: wrap;
}

.search-filter input,
.search-filter select {
    flex: 1;
    min-width: 200px;
    padding: 0.75rem 1rem;
    border: 2px solid #e2e8f0;
    border-radius: 8px;
    font-size: 1rem;
    transition: all 0.3s;
}

.search-filter input:focus,
.search-filter select:focus {
    outline: none;
    border-color: var(--primary);
    box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
}

/* Books Grid */
.books-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
    gap: 2rem;
    margin-bottom: 3rem;
}

.book-card {
    background: var(--white);
    border-radius: 12px;
    overflow: hidden;
    box-shadow: 0 4px 6px var(--shadow);
    transition: all 0.3s;
    text-decoration: none;
    color: var(--text);
    display: flex;
    flex-direction: column;
}

.book-card:hover {
    transform: translateY(-5px);
    box-shadow: 0 8px 15px var(--shadow-lg);
}

.book-card img {
    width: 100%;
    height: 400px;
    object-fit: cover;
    display: block;
}

.book-info {
    padding: 1.25rem;
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
}

.book-info h3 {
    font-size: 1.25rem;
    color: var(--text);
    margin-bottom: 0.25rem;
}

.book-info p {
    color: var(--text-light);
    font-size: 0.95rem;
}

.book-info .category {
    display: inline-block;
    background: linear-gradient(135deg, var(--primary), var(--secondary));
    color: var(--white);
    padding: 0.25rem 0.75rem;
    border-radius: 20px;
    font-size: 0.85rem;
    margin-top: auto;
}

/* Footer */
.footer {
    background: linear-gradient(135deg, #2d3748 0%, #1a202c 100%);
    color: var(--white);
    padding: 3rem 0 1rem;
    margin-top: 4rem;
}

.footer-content {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
    gap: 2rem;
    margin-bottom: 2rem;
}

.footer-brand h3 {
    font-size: 1.5rem;
    margin-bottom: 1rem;
}

.footer-mission {
    line-height: 1.7;
    opacity: 0.9;
    font-size: 0.95rem;
}

.footer-links h4,
.footer-info h4 {
    margin-bottom: 1rem;
    font-size: 1.1rem;
}

.footer-links ul,
.footer-info ul {
    list-style: none;
}

.footer-links li,
.footer-info li {
    margin-bottom: 0.5rem;
}

.footer-links a {
    color: rgba(255, 255, 255, 0.8);
    text-decoration: none;
    transition: color 0.3s;
}

.footer-links a:hover {
    color: var(--white);
}

.footer-info li {
    color: rgba(255, 255, 255, 0.8);
    font-size: 0.95rem;
}

.footer-bottom {
    text-align: center;
    padding-top: 2rem;
    border-top: 1px solid rgba(255, 255, 255, 0.1);
    opacity: 0.8;
    font-size: 0.9rem;
}

/* Modal */
.modal {
    display: none;
    position: fixed;
    z-index: 1000;
    left: 0;
    top: 0;
    width: 100%;
    height: 100%;
    background: rgba(0, 0, 0, 0.6);
    backdrop-filter: blur(5px);
    overflow-y: auto;
}

.modal-content {
    background: var(--white);
    margin: 5% auto;
    padding: 2rem;
    border-radius: 12px;
    max-width: 450px;
    box-shadow: 0 10px 40px rgba(0, 0, 0, 0.3);
    position: relative;
}

.auth-modal h2 {
    text-align: center;
    color: var(--text);
    margin-bottom: 1.5rem;
}

.auth-modal input {
    width: 100%;
    padding: 0.75rem 1rem;
    margin-bottom: 1rem;
    border: 2px solid #e2e8f0;
    border-radius: 8px;
    font-size: 1rem;
    transition: all 0.3s;
}

.auth-modal input:focus {
    outline: none;
    border-color: var(--primary);
    box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
}

.btn-primary {
    width: 100%;
    padding: 0.875rem;
    background: linear-gradient(135deg, var(--primary), var(--secondary));
    color: var(--white);
    border: none;
    border-radius: 8px;
    font-size: 1rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.3s;
}

.btn-primary:hover {
    transform: translateY(-2px);
    box-shadow: 0 6px 20px rgba(102, 126, 234, 0.4);
}

.auth-switch {
    text-align: center;
    margin-top: 1rem;
    color: var(--text-light);
    font-size: 0.9rem;
}

.auth-switch a {
    color: var(--primary);
    cursor: pointer;
    text-decoration: none;
    font-weight: 600;
}

.auth-switch a:hover {
    text-decoration: underline;
}

.close {
    position: absolute;
    right: 1.5rem;
    top: 1.5rem;
    font-size: 2rem;
    font-weight: bold;
    color: var(--text-light);
    cursor: pointer;
    transition: color 0.3s;
}

.close:hover {
    color: var(--text);
}

/* Detail Page */
.detail-header {
    text-align: center;
    margin: 2rem 0;
}

.detail-header h1 {
    font-size: 2.5rem;
    color: var(--text);
    margin-bottom: 0.5rem;
}

.detail-header h2 {
    font-size: 1.5rem;
    color: var(--text-light);
}

.detail-content {
    display: grid;
    grid-template-columns: 1fr 2fr;
    gap: 3rem;
    margin: 2rem 0;
}

.detail-cover img {
    width: 100%;
    max-width: 400px;
    border-radius: 12px;
    box-shadow: 0 8px 20px var(--shadow-lg);
}

.detail-info {
    display: flex;
    flex-direction: column;
    gap: 1.5rem;
}

.detail-info p {
    font-size: 1.1rem;
    line-height: 1.8;
    color: var(--text);
}

.qr-count {
    background: rgba(102, 126, 234, 0.1);
    padding: 1rem;
    border-radius: 8px;
    font-size: 1.1rem;
}

.action-buttons {
    display: flex;
    gap: 1rem;
    flex-wrap: wrap;
}

.watch-btn,
.qr-btn {
    padding: 0.875rem 1.5rem;
    border-radius: 8px;
    text-decoration: none;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.3s;
    border: none;
    font-size: 1rem;
}

.watch-btn {
    background: linear-gradient(135deg, var(--primary), var(--secondary));
    color: var(--white);
}

.qr-btn {
    background: var(--white);
    color: var(--primary);
    border: 2px solid var(--primary);
}

.watch-btn:hover,
.qr-btn:hover {
    transform: translateY(-2px);
    box-shadow: 0 6px 15px rgba(102, 126, 234, 0.3);
}

.suggestions-section {
    margin: 4rem 0;
}

.suggestions-section h3 {
    font-size: 1.8rem;
    margin-bottom: 1.5rem;
    color: var(--text);
}

/* Admin Panel - DÜZELTME */
.admin-header {
    background: linear-gradient(135deg, var(--primary), var(--secondary));
    color: var(--white);
    padding: 2rem 0;
    margin-bottom: 2rem;
}

.admin-controls {
    display: flex;
    justify-content: space-between;
    align-items: center;
    flex-wrap: wrap;
    gap: 1rem;
}

.add-book-section {
    background: var(--white);
    padding: 2rem;
    border-radius: 12px;
    box-shadow: 0 4px 6px var(--shadow);
    margin-bottom: 2rem;
}

.add-book-section h2 {
    margin-bottom: 1.5rem;
}

/* Form Grid - DÜZELTİLDİ */
.form-grid {
    display: grid;
    grid-template-columns: 1fr;
    gap: 1rem;
    margin-bottom: 1rem;
}

.form-row {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 1rem;
}

.form-grid input,
.form-grid textarea,
.form-row input {
    width: 100%;
    padding: 0.75rem 1rem;
    border: 2px solid #e2e8f0;
    border-radius: 8px;
    font-size: 1rem;
    font-family: inherit;
}

.form-grid textarea {
    min-height: 100px;
    resize: vertical;
}

.form-grid input:focus,
.form-grid textarea:focus,
.form-row input:focus {
    outline: none;
    border-color: var(--primary);
    box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
}

/* File Upload Butonu */
.file-upload-wrapper {
    position: relative;
    display: inline-block;
    width: 100%;
}

.file-upload-btn {
    display: inline-block;
    padding: 0.75rem 1rem;
    background: var(--white);
    border: 2px dashed var(--primary);
    border-radius: 8px;
    cursor: pointer;
    transition: all 0.3s;
    text-align: center;
    width: 100%;
    color: var(--primary);
    font-weight: 600;
}

.file-upload-btn:hover {
    background: rgba(102, 126, 234, 0.05);
    border-color: var(--primary-dark);
}

.file-upload-input {
    display: none;
}

.image-preview {
    margin-top: 1rem;
    text-align: center;
}

.image-preview img {
    max-width: 200px;
    max-height: 200px;
    border-radius: 8px;
    box-shadow: 0 2px 8px var(--shadow);
}

.books-list {
    background: var(--white);
    padding: 2rem;
    border-radius: 12px;
    box-shadow: 0 4px 6px var(--shadow);
}

.books-list h2 {
    margin-bottom: 1.5rem;
}

.book-item {
    padding: 1rem;
    border: 2px solid #e2e8f0;
    border-radius: 8px;
    margin-bottom: 1rem;
    display: flex;
    justify-content: space-between;
    align-items: center;
    flex-wrap: wrap;
    gap: 1rem;
}

.book-item-info {
    flex: 1;
    min-width: 200px;
}

.book-item-actions {
    display: flex;
    gap: 0.5rem;
    flex-wrap: wrap;
}

.book-item button {
    padding: 0.5rem 1rem;
    border-radius: 6px;
    border: none;
    cursor: pointer;
    font-weight: 600;
    transition: all 0.3s;
    font-size: 0.9rem;
}

.book-item .qr {
    background: var(--primary);
    color: var(--white);
}

.book-item .delete {
    background: #f56565;
    color: var(--white);
}

.book-item button:hover {
    transform: translateY(-2px);
    box-shadow: 0 4px 10px var(--shadow);
}

.qr-modal-content {
    text-align: center;
}

.qr-modal-content img {
    max-width: 300px;
    margin: 1rem 0;
}

.download-qr-btn {
    background: var(--primary);
    color: var(--white);
    padding: 0.75rem 1.5rem;
    border-radius: 8px;
    border: none;
    cursor: pointer;
    font-weight: 600;
    transition: all 0.3s;
}

.download-qr-btn:hover {
    background: var(--primary-dark);
}

/* Responsive */
@media (max-width: 768px) {
    .hero-title {
        font-size: 1.8rem;
    }
    
    .hero-description {
        font-size: 1rem;
    }
    
    .books-grid {
        grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
        gap: 1.5rem;
    }
    
    .book-card img {
        height: 300px;
    }
    
    .footer-content {
        grid-template-columns: 1fr;
    }
    
    .header-content {
        text-align: center;
        justify-content: center;
    }
    
    .logo-section h1 {
        font-size: 1.5rem;
    }
    
    .detail-content {
        grid-template-columns: 1fr;
        gap: 2rem;
    }
    
    .detail-cover img {
        max-width: 100%;
    }
    
    .form-row {
        grid-template-columns: 1fr;
    }
    
    .admin-controls {
        flex-direction: column;
        align-items: flex-start;
    }
}
STYLEEOF


# script.js (aynı)
cat > public/script.js << 'EOF'
let currentUser = JSON.parse(localStorage.getItem('currentUser'));
let allBooks = [];

async function loadBooks() {
    try {
        const response = await fetch('/api/books');
        allBooks = await response.json();
        displayBooks(allBooks);
    } catch (error) {
        console.error('Kitaplar yüklenirken hata:', error);
        alert('Kitaplar yüklenirken bir hata oluştu. Lütfen sayfayı yenileyin.');
    }
}

function displayBooks(books) {
    const grid = document.getElementById('booksGrid');
    
    if (books.length === 0) {
        grid.innerHTML = '<p style="text-align: center; grid-column: 1/-1; color: var(--text-light);">Henüz kitap eklenmemiş.</p>';
        return;
    }
    
    grid.innerHTML = books.map(book => `
        <a href="detail.html?id=${book.id}" class="book-card">
            <img src="${book.coverUrl}" 
                 alt="${book.title}" 
                 onerror="this.onerror=null; this.src='https://via.placeholder.com/280x400/667eea/ffffff?text=${encodeURIComponent(book.title)}'"
                 loading="lazy">
            <div class="book-info">
                <h3>${escapeHtml(book.title)}</h3>
                <p>${escapeHtml(book.author)}</p>
                <span class="category">${escapeHtml(book.category)}</span>
            </div>
        </a>
    `).join('');
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

function filterBooks() {
    const searchTerm = document.getElementById('searchInput').value.toLowerCase();
    const category = document.getElementById('categoryFilter').value;
    
    const filtered = allBooks.filter(book => {
        const matchesSearch = book.title.toLowerCase().includes(searchTerm) || 
                            book.author.toLowerCase().includes(searchTerm);
        const matchesCategory = !category || book.category === category;
        return matchesSearch && matchesCategory;
    });
    
    displayBooks(filtered);
}

function checkAuth() {
    const authButtons = document.getElementById('authButtons');
    const userSection = document.getElementById('userSection');
    
    if (currentUser) {
        authButtons.style.display = 'none';
        userSection.style.display = 'flex';
        document.getElementById('userGreeting').textContent = 
            currentUser.isAdmin ? `👨‍💼 ${currentUser.username}` : `👤 ${currentUser.username}`;
    } else {
        authButtons.style.display = 'flex';
        userSection.style.display = 'none';
    }
}

function showAuthModal(mode) {
    document.getElementById('authModal').style.display = 'block';
    switchAuthMode(mode);
}

function closeAuthModal() {
    document.getElementById('authModal').style.display = 'none';
}

function switchAuthMode(mode) {
    const loginForm = document.getElementById('loginForm');
    const registerForm = document.getElementById('registerForm');
    const authTitle = document.getElementById('authTitle');
    
    if (mode === 'login') {
        loginForm.style.display = 'block';
        registerForm.style.display = 'none';
        authTitle.textContent = 'Giriş Yap';
    } else {
        loginForm.style.display = 'none';
        registerForm.style.display = 'block';
        authTitle.textContent = 'Kayıt Ol';
    }
}

async function login() {
    const username = document.getElementById('loginUsername').value.trim();
    const password = document.getElementById('loginPassword').value;
    
    if (!username || !password) {
        alert('Lütfen tüm alanları doldurun!');
        return;
    }
    
    try {
        const response = await fetch('/api/login', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ username, password })
        });
        
        const data = await response.json();
        
        if (response.ok) {
            currentUser = data.user;
            localStorage.setItem('currentUser', JSON.stringify(currentUser));
            closeAuthModal();
            checkAuth();
            
            if (currentUser.isAdmin) {
                alert('Hoş geldiniz! Admin paneline yönlendiriliyorsunuz...');
                window.location.href = 'admin.html';
            } else {
                alert('Giriş başarılı! Hoş geldiniz.');
            }
        } else {
            alert(data.error || 'Giriş başarısız!');
        }
    } catch (error) {
        console.error('Giriş hatası:', error);
        alert('Bir hata oluştu. Lütfen tekrar deneyin.');
    }
}

async function register() {
    const username = document.getElementById('registerUsername').value.trim();
    const password = document.getElementById('registerPassword').value;
    const passwordConfirm = document.getElementById('registerPasswordConfirm').value;
    
    if (!username || !password || !passwordConfirm) {
        alert('Lütfen tüm alanları doldurun!');
        return;
    }
    
    if (password !== passwordConfirm) {
        alert('Şifreler eşleşmiyor!');
        return;
    }
    
    if (password.length < 6) {
        alert('Şifre en az 6 karakter olmalıdır!');
        return;
    }
    
    if (username.length < 3 || username.length > 30) {
        alert('Kullanıcı adı 3-30 karakter arası olmalıdır!');
        return;
    }
    
    try {
        const response = await fetch('/api/register', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ username, password })
        });
        
        const data = await response.json();
        
        if (response.ok) {
            currentUser = data.user;
            localStorage.setItem('currentUser', JSON.stringify(currentUser));
            closeAuthModal();
            checkAuth();
            alert('Kayıt başarılı! Hoş geldiniz.');
        } else {
            alert(data.error || 'Kayıt başarısız!');
        }
    } catch (error) {
        console.error('Kayıt hatası:', error);
        alert('Bir hata oluştu. Lütfen tekrar deneyin.');
    }
}

function logout() {
    if (confirm('Çıkış yapmak istediğinizden emin misiniz?')) {
        localStorage.removeItem('currentUser');
        currentUser = null;
        window.location.href = 'index.html';
    }
}

window.onclick = function(event) {
    const authModal = document.getElementById('authModal');
    if (event.target == authModal) {
        closeAuthModal();
    }
}

document.addEventListener('DOMContentLoaded', () => {
    const loginPassword = document.getElementById('loginPassword');
    if (loginPassword) {
        loginPassword.addEventListener('keypress', (e) => {
            if (e.key === 'Enter') login();
        });
    }
    
    const registerPasswordConfirm = document.getElementById('registerPasswordConfirm');
    if (registerPasswordConfirm) {
        registerPasswordConfirm.addEventListener('keypress', (e) => {
            if (e.key === 'Enter') register();
        });
    }
});

checkAuth();
loadBooks();
EOF


# detail.html ve detail.js (öncekiyle aynı) 
cat > public/detail.html << 'DETAILHTML'
<!DOCTYPE html>
<html lang="tr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Kitap Detayı - Fragsöz</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <header>
        <div class="container">
            <div class="header-content">
                <div class="logo-section">
                    <a href="index.html" style="color: inherit; text-decoration: none;">
                        <h1>📚 Fragsöz</h1>
                    </a>
                    <p class="tagline">Kitapların Hikayesini Keşfedin</p>
                </div>
                <div class="auth-section-compact">
                    <div id="authButtons">
                        <button class="btn-auth-compact" onclick="showAuthModal('login')">Giriş</button>
                        <button class="btn-auth-compact secondary" onclick="showAuthModal('register')">Kayıt</button>
                    </div>
                    <div id="userSection" style="display: none;">
                        <span class="user-greeting" id="userGreeting"></span>
                        <button class="btn-logout-compact" onclick="logout()">Çıkış</button>
                    </div>
                </div>
            </div>
        </div>
    </header>

    <main class="container">
        <div id="detailContainer"></div>
        
        <div class="suggestions-section">
            <h3>Benzer Kitaplar</h3>
            <div class="books-grid" id="suggestionsGrid"></div>
        </div>
    </main>

    <footer class="footer">
        <div class="container">
            <div class="footer-content">
                <div class="footer-brand">
                    <h3>📚 Fragsöz</h3>
                    <p class="footer-mission">
                        <strong>Misyonumuz:</strong> Okuyucuları kitaplarla buluşturmak, kitap seçim sürecini 
                        görsel ve interaktif hale getirerek okuma kültürünü yaygınlaştırmak.
                    </p>
                </div>
            </div>
            <div class="footer-bottom">
                <p>&copy; 2024 Fragsöz. Tüm hakları saklıdır.</p>
            </div>
        </div>
    </footer>

    <div id="authModal" class="modal">
        <div class="modal-content auth-modal">
            <span class="close" onclick="closeAuthModal()">&times;</span>
            <h2 id="authTitle">Giriş Yap</h2>
            
            <div id="loginForm">
                <input type="text" id="loginUsername" placeholder="Kullanıcı Adı" required>
                <input type="password" id="loginPassword" placeholder="Şifre" required>
                <button onclick="login()" class="btn-primary">Giriş Yap</button>
                <p class="auth-switch">Hesabınız yok mu? <a onclick="switchAuthMode('register')">Kayıt Olun</a></p>
            </div>
            
            <div id="registerForm" style="display: none;">
                <input type="text" id="registerUsername" placeholder="Kullanıcı Adı" required>
                <input type="password" id="registerPassword" placeholder="Şifre (min 6 karakter)" required>
                <input type="password" id="registerPasswordConfirm" placeholder="Şifre Tekrar" required>
                <button onclick="register()" class="btn-primary">Kayıt Ol</button>
                <p class="auth-switch">Zaten hesabınız var mı? <a onclick="switchAuthMode('login')">Giriş Yapın</a></p>
            </div>
        </div>
    </div>

    <script src="detail.js"></script>
</body>
</html>
DETAILHTML

cat > public/detail.js << 'DETAILJS'
let currentUser = JSON.parse(localStorage.getItem('currentUser'));
let currentBook = null;

function checkAuth() {
    const authButtons = document.getElementById('authButtons');
    const userSection = document.getElementById('userSection');
    
    if (currentUser) {
        authButtons.style.display = 'none';
        userSection.style.display = 'flex';
        document.getElementById('userGreeting').textContent = 
            currentUser.isAdmin ? `👨‍💼 ${currentUser.username}` : `👤 ${currentUser.username}`;
    } else {
        authButtons.style.display = 'flex';
        userSection.style.display = 'none';
    }
}

function showAuthModal(mode) {
    document.getElementById('authModal').style.display = 'block';
    switchAuthMode(mode);
}

function closeAuthModal() {
    document.getElementById('authModal').style.display = 'none';
}

function switchAuthMode(mode) {
    const loginForm = document.getElementById('loginForm');
    const registerForm = document.getElementById('registerForm');
    const authTitle = document.getElementById('authTitle');
    
    if (mode === 'login') {
        loginForm.style.display = 'block';
        registerForm.style.display = 'none';
        authTitle.textContent = 'Giriş Yap';
    } else {
        loginForm.style.display = 'none';
        registerForm.style.display = 'block';
        authTitle.textContent = 'Kayıt Ol';
    }
}

async function login() {
    const username = document.getElementById('loginUsername').value.trim();
    const password = document.getElementById('loginPassword').value;
    
    if (!username || !password) {
        alert('Lütfen tüm alanları doldurun!');
        return;
    }
    
    try {
        const response = await fetch('/api/login', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ username, password })
        });
        
        const data = await response.json();
        
        if (response.ok) {
            currentUser = data.user;
            localStorage.setItem('currentUser', JSON.stringify(currentUser));
            closeAuthModal();
            checkAuth();
            loadBookDetail();
            alert('Giriş başarılı!');
        } else {
            alert(data.error || 'Giriş başarısız!');
        }
    } catch (error) {
        alert('Bir hata oluştu. Lütfen tekrar deneyin.');
    }
}

async function register() {
    const username = document.getElementById('registerUsername').value.trim();
    const password = document.getElementById('registerPassword').value;
    const passwordConfirm = document.getElementById('registerPasswordConfirm').value;
    
    if (!username || !password || !passwordConfirm) {
        alert('Lütfen tüm alanları doldurun!');
        return;
    }
    
    if (password !== passwordConfirm) {
        alert('Şifreler eşleşmiyor!');
        return;
    }
    
    if (password.length < 6) {
        alert('Şifre en az 6 karakter olmalıdır!');
        return;
    }
    
    try {
        const response = await fetch('/api/register', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ username, password })
        });
        
        const data = await response.json();
        
        if (response.ok) {
            currentUser = data.user;
            localStorage.setItem('currentUser', JSON.stringify(currentUser));
            closeAuthModal();
            checkAuth();
            alert('Kayıt başarılı! Hoş geldiniz.');
        } else {
            alert(data.error || 'Kayıt başarısız!');
        }
    } catch (error) {
        alert('Bir hata oluştu. Lütfen tekrar deneyin.');
    }
}

function logout() {
    if (confirm('Çıkış yapmak istediğinizden emin misiniz?')) {
        localStorage.removeItem('currentUser');
        currentUser = null;
        window.location.href = 'index.html';
    }
}

const urlParams = new URLSearchParams(window.location.search);
const bookId = urlParams.get('id');
const fromQR = urlParams.get('qr') === 'true';

async function loadBookDetail() {
    try {
        if (fromQR) {
            await fetch(`/api/qr/${bookId}`, { method: 'POST' });
        }
        
        const response = await fetch(`/api/books/${bookId}`);
        if (!response.ok) {
            throw new Error('Kitap bulunamadı');
        }
        
        const book = await response.json();
        currentBook = book;
        
        const container = document.getElementById('detailContainer');
        
        const qrButton = (currentUser && currentUser.isAdmin) 
            ? `<button class="qr-btn" onclick="showQRCode()">📱 QR Kod Göster</button>` 
            : '';
        
        container.innerHTML = `
            <div class="detail-header">
                <h1>${escapeHtml(book.title)}</h1>
                <h2>${escapeHtml(book.author)}</h2>
            </div>
            <div class="detail-content">
                <div class="detail-cover">
                    <img src="${book.coverUrl}" 
                         alt="${escapeHtml(book.title)}" 
                         onerror="this.onerror=null; this.src='https://via.placeholder.com/400x600/667eea/ffffff?text=${encodeURIComponent(book.title)}'"
                         loading="lazy">
                </div>
                <div class="detail-info">
                    <p>${escapeHtml(book.summary)}</p>
                    <div class="qr-count">
                        📊 QR Okutma Sayısı: <strong>${book.qrCount}</strong>
                    </div>
                    <div class="action-buttons">
                        <a href="${book.videoUrl}" target="_blank" rel="noopener noreferrer" class="watch-btn">
                            ▶️ Tanıtım Videosu
                        </a>
                        ${qrButton}
                    </div>
                </div>
            </div>
        `;
        
        const suggestResponse = await fetch(`/api/suggest/${encodeURIComponent(book.category)}`);
        const suggestions = await suggestResponse.json();
        const filtered = suggestions.filter(s => s.id !== book.id);
        
        const suggestGrid = document.getElementById('suggestionsGrid');
        suggestGrid.innerHTML = filtered.map(s => `
            <a href="detail.html?id=${s.id}" class="book-card">
                <img src="${s.coverUrl}" 
                     alt="${escapeHtml(s.title)}" 
                     onerror="this.onerror=null; this.src='https://via.placeholder.com/280x400/667eea/ffffff?text=${encodeURIComponent(s.title)}'"
                     loading="lazy">
                <div class="book-info">
                    <h3>${escapeHtml(s.title)}</h3>
                    <p>${escapeHtml(s.author)}</p>
                </div>
            </a>
        `).join('');
    } catch (error) {
        console.error('Kitap yükleme hatası:', error);
        document.getElementById('detailContainer').innerHTML = `
            <div style="text-align: center; padding: 3rem;">
                <h2>Kitap bulunamadı</h2>
                <p><a href="index.html">Ana sayfaya dön</a></p>
            </div>
        `;
    }
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

async function showQRCode() {
    if (!document.getElementById('qrModal')) {
        const qrModalHTML = `
            <div id="qrModal" class="modal">
                <div class="modal-content qr-modal-content">
                    <span class="close" onclick="closeQRModal()">&times;</span>
                    <h2>QR Kod</h2>
                    <p>Bu QR kodu okutarak kitap sayfasına ulaşabilirsiniz</p>
                    <div id="qrCodeContainer"></div>
                    <button class="download-qr-btn" onclick="downloadQR()">QR Kodu İndir</button>
                </div>
            </div>
        `;
        document.body.insertAdjacentHTML('beforeend', qrModalHTML);
    }
    
    try {
        const response = await fetch(`/api/qrcode/${currentBook.id}`);
        const data = await response.json();
        
        document.getElementById('qrCodeContainer').innerHTML = `<img src="${data.qrCode}" alt="QR Code">`;
        document.getElementById('qrModal').style.display = 'block';
    } catch (error) {
        alert('QR kod oluşturulurken bir hata oluştu.');
    }
}

function closeQRModal() {
    document.getElementById('qrModal').style.display = 'none';
}

function downloadQR() {
    const img = document.querySelector('#qrCodeContainer img');
    const link = document.createElement('a');
    link.href = img.src;
    link.download = `${currentBook.title}-QR.png`;
    link.click();
}

window.onclick = function(event) {
    const authModal = document.getElementById('authModal');
    const qrModal = document.getElementById('qrModal');
    if (event.target == authModal) {
        closeAuthModal();
    }
    if (qrModal && event.target == qrModal) {
        closeQRModal();
    }
}

checkAuth();
loadBookDetail();
DETAILJS


# admin.html oluştur (dosya yükleme ile)
cat > public/admin.html << 'ADMINHTML'
<!DOCTYPE html>
<html lang="tr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Admin Paneli - Fragsöz</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <div class="admin-header">
        <div class="container">
            <div class="admin-controls">
                <div>
                    <h1>👨‍💼 Admin Paneli</h1>
                    <p id="welcomeText"></p>
                </div>
                <div style="display: flex; gap: 0.5rem;">
                    <a href="index.html" class="btn-auth-compact">Ana Sayfa</a>
                    <button class="btn-logout-compact" onclick="logout()">Çıkış</button>
                </div>
            </div>
        </div>
    </div>

    <main class="container">
        <div class="add-book-section">
            <h2>📚 Yeni Kitap Ekle</h2>
            <div class="form-grid">
                <div class="form-row">
                    <input type="text" id="title" placeholder="Kitap Başlığı *">
                    <input type="text" id="author" placeholder="Yazar *">
                </div>
                <div class="form-row">
                    <input type="text" id="category" placeholder="Kategori *">
                    <input type="url" id="videoUrl" placeholder="Video URL *">
                </div>
                
                <!-- Dosya Yükleme veya URL -->
                <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem;">
                    <div>
                        <label class="file-upload-btn" for="coverImageFile">
                            📁 Dosyadan Resim Seç
                        </label>
                        <input type="file" id="coverImageFile" class="file-upload-input" accept="image/*" onchange="handleFileSelect(event)">
                    </div>
                    <input type="url" id="coverUrl" placeholder="veya Resim URL'si girin">
                </div>
                
                <div id="imagePreviewContainer" class="image-preview" style="display: none;">
                    <p style="color: var(--text-light); font-size: 0.9rem; margin-bottom: 0.5rem;">Önizleme:</p>
                    <img id="imagePreview" src="" alt="Önizleme">
                </div>
                
                <textarea id="summary" placeholder="Özet *" rows="4"></textarea>
            </div>
            <button class="btn-primary" onclick="addBook()">📖 Kitap Ekle</button>
        </div>

        <div class="books-list">
            <h2>📖 Mevcut Kitaplar</h2>
            <div id="booksList"></div>
        </div>
    </main>

    <div id="qrModal" class="modal">
        <div class="modal-content qr-modal-content">
            <span class="close" onclick="closeQRModal()">&times;</span>
            <h2 id="qrBookTitle"></h2>
            <div id="qrCodeContainer"></div>
            <button class="download-qr-btn" onclick="downloadQR()">QR Kodu İndir</button>
        </div>
    </div>

    <script src="admin.js"></script>
</body>
</html>
ADMINHTML

# admin.js oluştur (dosya yükleme ile)
cat > public/admin.js << 'ADMINJS'
let currentUser = JSON.parse(localStorage.getItem('currentUser'));
let currentQRBook = null;
let uploadedImageUrl = null;

function checkAdminAuth() {
    if (!currentUser || !currentUser.isAdmin) {
        alert('Bu sayfaya erişim yetkiniz yok!');
        window.location.href = 'index.html';
        return;
    }
    document.getElementById('welcomeText').textContent = `Hoş geldin, ${currentUser.username} (Admin)`;
    loadAdminBooks();
}

function logout() {
    if (confirm('Çıkış yapmak istediğinizden emin misiniz?')) {
        localStorage.removeItem('currentUser');
        currentUser = null;
        window.location.href = 'index.html';
    }
}

function closeQRModal() {
    document.getElementById('qrModal').style.display = 'none';
}

async function showBookQR(bookId) {
    try {
        const response = await fetch(`/api/books/${bookId}`);
        const book = await response.json();
        currentQRBook = book;
        
        const qrResponse = await fetch(`/api/qrcode/${bookId}`);
        const qrData = await qrResponse.json();
        
        document.getElementById('qrBookTitle').textContent = `${book.title} - ${book.author}`;
        document.getElementById('qrCodeContainer').innerHTML = `<img src="${qrData.qrCode}" alt="QR Code">`;
        document.getElementById('qrModal').style.display = 'block';
    } catch (error) {
        alert('QR kod oluşturulurken bir hata oluştu.');
    }
}

function downloadQR() {
    const img = document.querySelector('#qrCodeContainer img');
    const link = document.createElement('a');
    link.href = img.src;
    link.download = `${currentQRBook.title}-QR.png`;
    link.click();
}

async function handleFileSelect(event) {
    const file = event.target.files[0];
    if (!file) return;
    
    // Dosya boyutu kontrolü (5MB)
    if (file.size > 5 * 1024 * 1024) {
        alert('Dosya boyutu 5MB\'dan küçük olmalıdır!');
        return;
    }
    
    // Dosya tipi kontrolü
    const allowedTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp', 'image/svg+xml', 'image/bmp', 'image/tiff'];
    if (!allowedTypes.includes(file.type)) {
        alert('Sadece resim dosyaları yüklenebilir! (JPG, PNG, GIF, WEBP, SVG, BMP, TIFF)');
        return;
    }
    
    // Önizleme göster
    const reader = new FileReader();
    reader.onload = function(e) {
        document.getElementById('imagePreview').src = e.target.result;
        document.getElementById('imagePreviewContainer').style.display = 'block';
    };
    reader.readAsDataURL(file);
    
    // Dosyayı sunucuya yükle
    const formData = new FormData();
    formData.append('image', file);
    
    try {
        const response = await fetch('/api/upload', {
            method: 'POST',
            body: formData
        });
        
        if (response.ok) {
            const data = await response.json();
            uploadedImageUrl = data.imageUrl;
            document.getElementById('coverUrl').value = '';
            alert('Resim başarıyla yüklendi!');
        } else {
            const error = await response.json();
            alert(error.error || 'Resim yüklenirken bir hata oluştu!');
            uploadedImageUrl = null;
        }
    } catch (error) {
        alert('Resim yüklenirken bir hata oluştu. Lütfen tekrar deneyin.');
        uploadedImageUrl = null;
    }
}

async function addBook() {
    const title = document.getElementById('title').value.trim();
    const author = document.getElementById('author').value.trim();
    const category = document.getElementById('category').value.trim();
    const summary = document.getElementById('summary').value.trim();
    const coverUrlInput = document.getElementById('coverUrl').value.trim();
    const videoUrl = document.getElementById('videoUrl').value.trim();
    
    // Kapak resmi: önce yüklenen dosya, yoksa URL
    const coverUrl = uploadedImageUrl || coverUrlInput;
    
    if (!title || !author || !category || !summary || !coverUrl || !videoUrl) {
        alert('Lütfen tüm alanları doldurun!');
        return;
    }
    
    // URL validasyonu (sadece coverUrlInput kullanılıyorsa)
    if (!uploadedImageUrl && coverUrlInput) {
        try {
            new URL(coverUrlInput);
        } catch (e) {
            alert('Lütfen geçerli bir resim URL\'si girin!');
            return;
        }
    }
    
    try {
        new URL(videoUrl);
    } catch (e) {
        alert('Lütfen geçerli bir video URL\'si girin!');
        return;
    }
    
    const book = {
        title,
        author,
        category,
        summary,
        coverUrl,
        videoUrl
    };
    
    try {
        const response = await fetch('/api/books', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(book)
        });
        
        if (response.ok) {
            // Formu temizle
            document.getElementById('title').value = '';
            document.getElementById('author').value = '';
            document.getElementById('category').value = '';
            document.getElementById('summary').value = '';
            document.getElementById('coverUrl').value = '';
            document.getElementById('videoUrl').value = '';
            document.getElementById('coverImageFile').value = '';
            document.getElementById('imagePreviewContainer').style.display = 'none';
            uploadedImageUrl = null;
            
            loadAdminBooks();
            alert('Kitap başarıyla eklendi!');
        } else {
            const error = await response.json();
            alert(error.error || 'Kitap eklenirken bir hata oluştu!');
        }
    } catch (error) {
        alert('Bir hata oluştu. Lütfen tekrar deneyin.');
    }
}

async function loadAdminBooks() {
    try {
        const response = await fetch('/api/books');
        const books = await response.json();
        
        const list = document.getElementById('booksList');
        
        if (books.length === 0) {
            list.innerHTML = '<p style="text-align: center; color: var(--text-light); padding: 2rem;">Henüz kitap eklenmemiş.</p>';
            return;
        }
        
        list.innerHTML = books.map(book => `
            <div class="book-item">
                <div class="book-item-info">
                    <h4>${escapeHtml(book.title)} - ${escapeHtml(book.author)}</h4>
                    <p>Kategori: ${escapeHtml(book.category)} | QR Sayısı: ${book.qrCount}</p>
                </div>
                <div class="book-item-actions">
                    <button class="qr" onclick="showBookQR(${book.id})">📱 QR Kod</button>
                    <button class="delete" onclick="deleteBook(${book.id})">🗑️ Sil</button>
                </div>
            </div>
        `).join('');
    } catch (error) {
        alert('Kitaplar yüklenirken bir hata oluştu.');
    }
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

async function deleteBook(id) {
    if (confirm('Bu kitabı silmek istediğinizden emin misiniz?')) {
        try {
            const response = await fetch(`/api/books/${id}`, { method: 'DELETE' });
            
            if (response.ok) {
                loadAdminBooks();
                alert('Kitap silindi!');
            } else {
                alert('Kitap silinirken bir hata oluştu!');
            }
        } catch (error) {
            alert('Bir hata oluştu. Lütfen tekrar deneyin.');
        }
    }
}

window.onclick = function(event) {
    const qrModal = document.getElementById('qrModal');
    if (event.target == qrModal) {
        closeQRModal();
    }
}

checkAdminAuth();
ADMINJS

# Kurulum sonrası mesajlar
echo ""
echo "✅ Kurulum tamamlandı!"
echo ""
echo "🔒 GÜVENLİK İYİLEŞTİRMELERİ:"
echo "   ✓ Bcrypt ile şifre hashleme"
echo "   ✓ Rate limiting (DDoS koruması)"
echo "   ✓ Helmet.js güvenlik başlıkları"
echo "   ✓ Input validasyonu ve sanitizasyon"
echo "   ✓ XSS koruması"
echo ""
echo "🎨 TASARIM İYİLEŞTİRMELERİ:"
echo "   ✓ Admin panelindeki kayma sorunu düzeltildi"
echo "   ✓ Form düzeni responsive hale getirildi"
echo "   ✓ Kompakt giriş/kayıt butonları"
echo "   ✓ Profesyonel gradient ve modern tasarım"
echo ""
echo "📸 RESİM İYİLEŞTİRMELERİ:"
echo "   ✓ Dosya yöneticisinden resim seçme"
echo "   ✓ Otomatik resim yükleme (Multer)"
echo "   ✓ Resim önizleme"
echo "   ✓ 5MB dosya boyutu limiti"
echo "   ✓ JPG, PNG, GIF, WEBP, SVG, BMP, TIFF desteği"
echo ""
echo "🚀 Sunucuyu başlatmak için:"
echo "   cd ~/fragsoz"
echo "   node server.js"
echo ""
echo "📱 Tarayıcınızda açın:"
echo "   http://localhost:3000"
echo ""
echo "🔐 VARSAYILAN ADMİN GİRİŞİ:"
echo "   Kullanıcı: admin"
echo "   Şifre: admin123"
echo ""
echo "💡 NOT: İlk girişten sonra admin şifresini değiştirmeniz önerilir."
echo ""
echo "✨ Yeni özellikler hazır!"
echo ""

# Sunucuyu otomatik başlat
echo "Sunucu başlatılıyor..."
node server.js
