import React from 'react';
import {
  List,
  Datagrid,
  TextField,
  TextInput,
  Create,
  Edit,
  SimpleForm,
  required,
} from 'react-admin';

export const DNSList = () => (
  <List>
    <Datagrid rowClick="edit">
      <TextField source="id" />
      <TextField source="nome_aluno" label="Nome do Aluno" />
      <TextField source="nome_dominio" label="Nome do Domínio" />
    </Datagrid>
  </List>
);

export const DNSCreate = () => (
  <Create>
    <SimpleForm>
      <TextInput source="nome_aluno" label="Nome do Aluno" validate={required()} />
      <TextInput source="nome_dominio" label="Nome do Domínio" validate={required()} />
    </SimpleForm>
  </Create>
);

export const DNSEdit = () => (
  <Edit>
    <SimpleForm>
      <TextInput source="nome_aluno" label="Nome do Aluno" validate={required()} />
      <TextInput source="nome_dominio" label="Nome do Domínio" validate={required()} />
    </SimpleForm>
  </Edit>
); 