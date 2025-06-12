import React from 'react';
import { Admin, Resource } from 'react-admin';
import { DataProvider } from './dataProvider';
import { DNSList, DNSCreate, DNSEdit } from './components/DNS';

const App = () => (
  <Admin dataProvider={DataProvider}>
    <Resource name="dns" list={DNSList} create={DNSCreate} edit={DNSEdit} />
  </Admin>
);

export default App; 