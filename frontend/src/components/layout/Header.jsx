import { useLocation } from 'react-router-dom';

const pageTitles = {
  '/': 'Home',
  '/colaboradores': 'Colaboradores',
};

const Header = () => {
  const location = useLocation();
  const title = pageTitles[location.pathname] || 'BSC BackOffice';

  return (
    <div className="header">
      <div className="header__left">
        <h1 className="text-xl font-semibold m-0">{title}</h1>
      </div>
    </div>
  );
};

export default Header;
