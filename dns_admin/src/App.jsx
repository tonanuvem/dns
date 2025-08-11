import { Admin, Resource, fetchUtils } from 'react-admin';
import simpleRestProvider from 'ra-data-simple-rest';
import React from 'react';

import {
  List,
  Datagrid,
  TextField,
  EditButton,
  DeleteButton,
} from 'react-admin';

import { Create, Edit, SimpleForm, TextInput } from 'react-admin';

// --- Variáveis de Ambiente ---
// VITE_API_URL deve ser a URL base da sua API Gateway.
// Ex: VITE_API_URL=https://tsll3rchh7.execute-api.us-east-1.amazonaws.com/prod
const apiUrl = import.meta.env.VITE_API_URL;
// VITE_API_KEY deve ser a chave da sua API.
// Ex: VITE_API_KEY=aluno
const apiKey = import.meta.env.VITE_API_KEY;

// --- Cliente HTTP Customizado para Incluir a API Key ---
// Este cliente será passado para o simpleRestProvider
const httpClient = (url, options = {}) => {
  if (!options.headers) {
    options.headers = new Headers({ Accept: 'application/json' });
  }
  // Adiciona o header X-API-Key a todas as requisições
  options.headers.set('x-api-key', apiKey);
  return fetchUtils.fetchJson(url, options);
};

// --- Data Provider ---
// Usamos simpleRestProvider diretamente, pois a API agora retorna um array de objetos
// e lida com o 'id' e 'Content-Range' como esperado.
const dataProvider = simpleRestProvider(apiUrl, httpClient);


export default function App() {
  return (
    <Admin dataProvider={dataProvider}>
      <Resource
        name='registros' // Nome do recurso (corresponde ao endpoint da API)
        list={RegistroList}
        create={RegistroCreate}
        edit={RegistroEdit}
      />
    </Admin>
  );
}

// --- Componente de Listagem (List) ---
const RegistroList = (props) => {
  return (
    <List {...props}>
      <Datagrid rowClick="edit">
        {/* As 'source' devem corresponder exatamente às chaves dos objetos retornados pela sua API */}
        <TextField source='alias' label="Subdomínio" />
        <TextField source='endereco_ip' label="Endereço IP" />
        <TextField source='data_criacao' label="Data de Criação" />
        {/* 'nameservers' não é um campo de cada registro individualmente, foi removido */}
        <EditButton basePath='/registros' />
        <DeleteButton basePath='/registros' />
      </Datagrid>
    </List>
  );
};

// --- Componente de Criação (Create) ---
const RegistroCreate = (props) => {
  return (
    <Create title='Criar Registro DNS' {...props}>
      <SimpleForm>
        {/* Os 'source' aqui devem corresponder aos nomes que sua API espera no POST */}
        <TextInput source='alias' label="Subdomínio" />
        <TextInput source='endereco_ip' label="Endereço IP" />
      </SimpleForm>
    </Create>
  );
};

// --- Componente de Edição (Edit) ---
const RegistroEdit = (props) => {
  return (
    <Edit title='Editar Registro DNS' {...props}>
      <SimpleForm>
        {/* 'alias' é a chave primária e geralmente não é editável */}
        <TextInput disabled source='alias' label="Subdomínio" />
        {/* A API espera 'endereco_ip' para edição */}
        <TextInput source='endereco_ip' label="Endereço IP" />
        {/* Campos 'fname' e 'lname' removidos, pois não fazem parte do seu modelo de dados */}
      </SimpleForm>
    </Edit>
  );
};