import React, { useState } from 'react';
import {
  Admin,
  Resource,
  fetchUtils,
  List,
  Datagrid,
  TextField,
  FunctionField,
  EditButton,
  DeleteButton,
  Create,
  Edit,
  SimpleForm,
  TextInput,
  TopToolbar,
  CreateButton,
  ExportButton,
  Layout,
  AppBar,
  TitlePortal,
  useRecordContext,
  useNotify,
  required,
  regex,
  defaultTheme,
} from 'react-admin';
import simpleRestProvider from 'ra-data-simple-rest';
import {
  Chip,
  Tooltip,
  Box,
  Button,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  TextField as MuiTextField,
  Typography,
  Link,
} from '@mui/material';
import LockIcon from '@mui/icons-material/Lock';
import LockOpenIcon from '@mui/icons-material/LockOpen';
import SchoolIcon from '@mui/icons-material/School';
import OpenInNewIcon from '@mui/icons-material/OpenInNew';

// ============================================================
// CONFIGURACAO
//
// VITE_API_KEY e a senha da TURMA: ela vai no bundle, que e publico.
// Serve para dizer "voce e desta turma", nunca "este registro e seu".
// A senha de INSTRUTOR nao mora aqui -- ela e digitada na tela e fica
// so no sessionStorage, para nao acabar dentro do bundle.
// ============================================================

const apiUrl = import.meta.env.VITE_API_URL;
const apiKey = import.meta.env.VITE_API_KEY;

const CHAVE_ADMIN = 'dns_admin_senha';

const lerSenhaAdmin = () => {
  try {
    return sessionStorage.getItem(CHAVE_ADMIN) || '';
  } catch {
    // Navegador com armazenamento bloqueado: segue sem modo instrutor.
    return '';
  }
};

const gravarSenhaAdmin = (valor) => {
  try {
    if (valor) sessionStorage.setItem(CHAVE_ADMIN, valor);
    else sessionStorage.removeItem(CHAVE_ADMIN);
  } catch {
    /* sem armazenamento, o modo instrutor vale so para esta aba */
  }
};

const httpClient = (url, options = {}) => {
  if (!options.headers) {
    options.headers = new Headers({ Accept: 'application/json' });
  }
  options.headers.set('x-api-key', apiKey);

  // So vai quando o instrutor preencheu a senha. Sem ela, a API trata
  // a requisicao como de aluno e recusa mexer em registro com dono.
  const senhaAdmin = lerSenhaAdmin();
  if (senhaAdmin) options.headers.set('x-admin-key', senhaAdmin);

  return fetchUtils.fetchJson(url, options);
};

const dataProvider = simpleRestProvider(apiUrl, httpClient);

// ============================================================
// TEMA
// ============================================================

const theme = {
  ...defaultTheme,
  palette: {
    ...defaultTheme.palette,
    primary: { main: '#0b5394' },
    secondary: { main: '#1a73e8' },
    background: { default: '#f4f6f8' },
  },
  typography: {
    ...defaultTheme.typography,
    fontFamily: '"Segoe UI", system-ui, -apple-system, Roboto, sans-serif',
    h6: { fontWeight: 600 },
  },
  components: {
    ...defaultTheme.components,
    MuiPaper: {
      styleOverrides: {
        elevation1: {
          boxShadow: '0 1px 3px rgba(0,0,0,.08), 0 1px 2px rgba(0,0,0,.06)',
        },
      },
    },
  },
};

// ============================================================
// MODO INSTRUTOR
//
// Registro criado pelo dns.sh tem dono, e a API recusa (403) alterar
// ou apagar sem o token do aluno. O instrutor usa a senha separada,
// que nunca entra no bundle.
// ============================================================

const BotaoInstrutor = () => {
  const [aberto, setAberto] = useState(false);
  const [senha, setSenha] = useState('');
  const [ativo, setAtivo] = useState(Boolean(lerSenhaAdmin()));
  const notify = useNotify();

  const salvar = () => {
    gravarSenhaAdmin(senha);
    setAtivo(Boolean(senha));
    setAberto(false);
    setSenha('');
    notify(
      senha ? 'Modo instrutor ativado nesta aba.' : 'Modo instrutor desligado.',
      { type: 'info' },
    );
    // A lista precisa ser refeita com o novo cabecalho.
    window.location.reload();
  };

  const desligar = () => {
    gravarSenhaAdmin('');
    setAtivo(false);
    window.location.reload();
  };

  return (
    <>
      <Tooltip
        title={
          ativo
            ? 'Modo instrutor ativo — você pode editar e apagar registros de alunos'
            : 'Entrar como instrutor para mexer em registros de alunos'
        }
      >
        <Button
          color="inherit"
          size="small"
          startIcon={<SchoolIcon />}
          onClick={() => (ativo ? desligar() : setAberto(true))}
        >
          {ativo ? 'Instrutor: ativo' : 'Instrutor'}
        </Button>
      </Tooltip>

      <Dialog open={aberto} onClose={() => setAberto(false)} maxWidth="xs" fullWidth>
        <DialogTitle>Modo instrutor</DialogTitle>
        <DialogContent>
          <Typography variant="body2" sx={{ mb: 2 }}>
            Registros criados pelos alunos pelo <code>dns.sh</code> pertencem a
            eles. Informe a senha de instrutor para poder editá-los ou
            apagá-los.
          </Typography>
          <Typography variant="caption" color="text.secondary">
            Não é a senha da turma. Para consultá-la:
            <code> grep senha_admin terraform/terraform.tfvars</code>
          </Typography>
          <MuiTextField
            autoFocus
            fullWidth
            type="password"
            margin="normal"
            label="Senha de instrutor"
            value={senha}
            onChange={(e) => setSenha(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && salvar()}
          />
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setAberto(false)}>Cancelar</Button>
          <Button variant="contained" onClick={salvar}>
            Ativar
          </Button>
        </DialogActions>
      </Dialog>
    </>
  );
};

const BarraSuperior = (props) => (
  <AppBar {...props} color="primary">
    <TitlePortal />
    <Box sx={{ flex: 1 }} />
    <BotaoInstrutor />
  </AppBar>
);

const LayoutApp = (props) => <Layout {...props} appBar={BarraSuperior} />;

// ============================================================
// LISTAGEM
// ============================================================

const ColunaDono = () => {
  const record = useRecordContext();
  if (!record) return null;

  return record.tem_dono ? (
    <Tooltip title="Criado por um aluno (dns.sh). Só o aluno, ou o instrutor, pode alterar.">
      <Chip
        size="small"
        icon={<LockIcon />}
        label="Aluno"
        color="warning"
        variant="outlined"
      />
    </Tooltip>
  ) : (
    <Tooltip title="Sem dono: qualquer um com a senha da turma pode alterar.">
      <Chip
        size="small"
        icon={<LockOpenIcon />}
        label="Livre"
        variant="outlined"
      />
    </Tooltip>
  );
};

// Botoes desabilitados quando o registro tem dono e o modo instrutor
// esta desligado -- antes a tela oferecia os dois e a API respondia
// 403, sem explicar por que.
const AcoesRegistro = () => {
  const record = useRecordContext();
  const bloqueado = record?.tem_dono && !lerSenhaAdmin();

  if (bloqueado) {
    return (
      <Tooltip title="Registro de aluno. Ative o modo instrutor para editar ou apagar.">
        <Box sx={{ display: 'inline-flex', opacity: 0.45 }}>
          <EditButton disabled />
          <DeleteButton disabled />
        </Box>
      </Tooltip>
    );
  }

  return (
    <Box sx={{ display: 'inline-flex' }}>
      <EditButton />
      <DeleteButton mutationMode="pessimistic" />
    </Box>
  );
};

const AcoesLista = () => (
  <TopToolbar>
    <CreateButton label="Novo registro" />
    <ExportButton label="Exportar" />
  </TopToolbar>
);

const RegistroList = () => (
  <List
    actions={<AcoesLista />}
    sort={{ field: 'alias', order: 'ASC' }}
    perPage={25}
    empty={false}
  >
    <Datagrid bulkActionButtons={false} rowClick={false}>
      <FunctionField
        label="Endereço"
        render={(record) => (
          <Box>
            <Link
              href={`http://${record.nome_completo}`}
              target="_blank"
              rel="noopener"
              underline="hover"
              sx={{ fontWeight: 600, display: 'inline-flex', alignItems: 'center', gap: 0.5 }}
            >
              {record.nome_completo}
              <OpenInNewIcon sx={{ fontSize: 14 }} />
            </Link>
            <Typography variant="caption" color="text.secondary" display="block">
              *.{record.nome_completo}
            </Typography>
          </Box>
        )}
      />
      <TextField source="endereco_ip" label="IP da VM" />
      <ColunaDono label="Origem" />
      <FunctionField
        label="Criado em"
        render={(record) =>
          record.data_criacao
            ? new Date(record.data_criacao).toLocaleString('pt-BR')
            : '—'
        }
      />
      <AcoesRegistro label="Ações" />
    </Datagrid>
  </List>
);

// ============================================================
// FORMULARIOS
//
// A validacao espelha a da API: errar aqui custa uma ida ao servidor
// e uma mensagem generica.
// ============================================================

const validaAlias = [
  required('Informe o subdomínio'),
  regex(
    /^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$/,
    'Só letras minúsculas, números e hífen. Sem ponto, sem começar ou terminar com hífen.',
  ),
  regex(/^(?!(api|www\d*|https\d*)$)/, 'Este nome é reservado pela infraestrutura.'),
];

const validaIp = [
  required('Informe o IP'),
  regex(
    /^((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)\.){3}(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)$/,
    'Informe um IPv4 válido, ex: 54.224.126.59',
  ),
];

const AjudaRegistro = () => (
  <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
    Serão criados dois registros apontando para o mesmo IP: o nome em si e
    o curinga <code>*.nome</code>, que permite servir várias aplicações da
    mesma VM através de um proxy reverso.
  </Typography>
);

const RegistroCreate = () => (
  <Create title="Novo registro DNS" redirect="list">
    <SimpleForm>
      <AjudaRegistro />
      <TextInput
        source="alias"
        label="Subdomínio"
        validate={validaAlias}
        helperText="Ex: joao — vira joao.<zona>"
        fullWidth
      />
      <TextInput
        source="endereco_ip"
        label="Endereço IP"
        validate={validaIp}
        helperText="IP público da VM"
        fullWidth
      />
    </SimpleForm>
  </Create>
);

const RegistroEdit = () => (
  <Edit title="Editar registro DNS" mutationMode="pessimistic" redirect="list">
    <SimpleForm>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
        O subdomínio é a chave do registro e não pode ser alterado. Para
        trocar de nome, apague e crie outro.
      </Typography>
      <TextInput source="alias" label="Subdomínio" disabled fullWidth />
      <TextInput
        source="endereco_ip"
        label="Endereço IP"
        validate={validaIp}
        fullWidth
      />
    </SimpleForm>
  </Edit>
);

// ============================================================

export default function App() {
  return (
    <Admin
      dataProvider={dataProvider}
      theme={theme}
      layout={LayoutApp}
      title="Gerenciador DNS"
      disableTelemetry
    >
      <Resource
        name="registros"
        options={{ label: 'Registros DNS' }}
        list={RegistroList}
        create={RegistroCreate}
        edit={RegistroEdit}
      />
    </Admin>
  );
}
