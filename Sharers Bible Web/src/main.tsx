import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { BrowserRouter, Routes, Route } from 'react-router-dom'
import './index.css'
import App from './App.tsx'
import ThemeProvider from './components/ThemeProvider'
import Privacy from './pages/Privacy.tsx'
import Terms from './pages/Terms.tsx'
import Contact from './pages/Contact.tsx'

if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/sw.js').catch(err => console.log('SW error', err));
  });
}

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <BrowserRouter>
      <ThemeProvider>
      <Routes>
        <Route path="/" element={<App />} />
        <Route path="/read/:lang/:version/:book/:chapter" element={<App />} />
        <Route path="/privacy" element={<Privacy />} />
        <Route path="/terms" element={<Terms />} />
        <Route path="/contact" element={<Contact />} />
      </Routes>
      </ThemeProvider>
    </BrowserRouter>
  </StrictMode>,
)
