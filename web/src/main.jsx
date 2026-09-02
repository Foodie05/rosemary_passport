import React from 'react';
import ReactDOM from 'react-dom/client';
import { BrowserRouter } from 'react-router-dom';
import App from './App';
import './styles.css';
import { ThemeProvider } from './theme';
import { RosemaryDialogProvider } from './components/ui';

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <ThemeProvider>
      <RosemaryDialogProvider>
        <BrowserRouter>
          <App />
        </BrowserRouter>
      </RosemaryDialogProvider>
    </ThemeProvider>
  </React.StrictMode>,
);
