import React from 'react';
import { Admin, Resource } from 'react-admin';
import { DataProvider } from './dataProvider';
import { DNSList, DNSCreate, DNSEdit } from './components/DNS';
import { Alert } from '@mui/material';

const App = () => {
  const [error, setError] = React.useState(null);
  const [info, setInfo] = React.useState(null);

  React.useEffect(() => {
    // Aqui você pode adicionar qualquer lógica de inicialização necessária
  }, []);

  if (error) return <Alert severity="error">{error}</Alert>;
  if (!info) return null;

  return (
    <Admin dataProvider={DataProvider}>
      <Resource name="dns" list={DNSList} create={DNSCreate} edit={DNSEdit} />
    </Admin>
  );
};

export default App; 