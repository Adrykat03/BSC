import './styles/main.css';
import AppRoutes from './routes';
import { SessionProvider } from './context/SessionContext';

const App = () => {
  return (
    <SessionProvider>
      <AppRoutes />
    </SessionProvider>
  );
};

export default App;
