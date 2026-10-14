import React from 'react';
import ReactDOM from 'react-dom/client';
import { BrowserRouter } from 'react-router-dom';
import App from './App';
import { RouteEffects } from './components/RouteEffects';
import { MotionPreferences } from './design/MotionPreferences';
import './styles.css';
import { ThemeProvider } from './theme';
import { RosemaryDialogProvider } from './components/ui';

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <MotionPreferences>
      <ThemeProvider>
      <RosemaryDialogProvider>
        <BrowserRouter>
          <RouteEffects />
          <App />
        </BrowserRouter>
      </RosemaryDialogProvider>
    </ThemeProvider>
    </MotionPreferences>
  </React.StrictMode>,
);
