import React, { useState, useEffect } from 'react';
import {
  Admin,
  Resource,
  List,
  Datagrid,
  TextField,
  DateField,
  Create,
  SimpleForm,
  TextInput,
  required,
  Edit,
  DeleteButton,
  Card,
  CardContent,
  Typography,
  Box,
  Alert,
} from 'react-admin';
import { dataProvider } from './dataProvider';

const InfoCard = () => {
  const [info, setInfo] = useState(null);
  const [error, setError] = useState(null);

  useEffect(() => {
    const fetchInfo = async () => {
      try {
        const response = await fetch('/info', {
          headers: {
            'X-API-Key': localStorage.getItem('apiKey'),
          },
        });
        if (!response.ok) throw new Error('Erro ao buscar informações');
        const data = await response.json();
        setInfo(data);
      } catch (err) {
        setError(err.message);
      }
    };

    fetchInfo();
  }, []);

  if (error) return <Alert severity="error">{error}</Alert>;
  if (!info) return null;

  return (
    <Card>
      <CardContent>
        <Typography variant="h6" gutterBottom>
          Informações da Zona DNS
        </Typography>
        <Box mb={2}>
          <Typography variant="subtitle1">Nameservers:</Typography>
          {info.nameservers.map((ns, index) => (
            <Typography key={index} variant="body2">
              {ns}
            </Typography>
          ))}
        </Box>
        <Box mb={2}>
          <Typography variant="subtitle1">ID da Zona:</Typography>
          <Typography variant="body2">{info.zona_id}</Typography>
        </Box>
        <Box>
          <Typography variant="subtitle1">TTL:</Typography>
          <Typography variant="body2">{info.ttl} segundos</Typography>
        </Box>
      </CardContent>
    </Card>
  );
};

const RegistroList = (props) => (
  <List {...props}>
    <Datagrid>
      <TextField source="subdominio" label="Subdomínio" />
      <TextField source="endereco_ip" label="Endereço IP" />
      <DateField source="data_criacao" label="Data de Criação" showTime />
      <DeleteButton />
    </Datagrid>
  </List>
);

const RegistroCreate = (props) => (
  <Create {...props}>
    <SimpleForm>
      <TextInput source="subdominio" label="Subdomínio" validate={required()} />
      <TextInput source="endereco_ip" label="Endereço IP" validate={required()} />
    </SimpleForm>
  </Create>
);

const RegistroEdit = (props) => (
  <Edit {...props}>
    <SimpleForm>
      <TextInput source="subdominio" label="Subdomínio" validate={required()} />
      <TextInput source="endereco_ip" label="Endereço IP" validate={required()} />
    </SimpleForm>
  </Edit>
);

const App = () => (
  <Admin dataProvider={dataProvider}>
    <Resource
      name="registros"
      list={RegistroList}
      create={RegistroCreate}
      edit={RegistroEdit}
    />
    <InfoCard />
  </Admin>
);

export default App; 