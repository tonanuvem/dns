import { fetchUtils } from 'react-admin';

// Obtém as variáveis de ambiente
const apiUrl = import.meta.env.VITE_API_URL || 'http://localhost:3000';
const apiKey = import.meta.env.VITE_API_KEY || 'aluno';

const httpClient = (url, options = {}) => {
  if (!options.headers) {
    options.headers = new Headers({ Accept: 'application/json' });
  }
  // Adiciona o header X-API-Key em todas as requisições
  options.headers.set('X-API-Key', apiKey);
  return fetchUtils.fetchJson(url, options);
};

export const DataProvider = {
  // A versão customizada funciona perfeitamente com a sua API.
  // Ela já resolve o problema de o backend retornar um objeto com a chave "registros".
  getList: async (resource, params) => {
    const { json } = await httpClient(`${apiUrl}/${resource}`);
    return {
      data: json.registros, // Ajustado para pegar a lista dentro do objeto
      total: json.registros.length,
    };
  },

  getOne: async (resource, params) => {
    const { json } = await httpClient(`${apiUrl}/${resource}/${params.id}`);
    return {
      data: json,
    };
  },

  create: async (resource, params) => {
    const { json } = await httpClient(`${apiUrl}/${resource}`, {
      method: 'POST',
      body: JSON.stringify(params.data),
    });
    return {
      data: { ...params.data, id: json.id },
    };
  },

  update: async (resource, params) => {
    const { json } = await httpClient(`${apiUrl}/${resource}/${params.id}`, {
      method: 'PUT',
      body: JSON.stringify(params.data),
    });
    return {
      data: json,
    };
  },

  delete: async (resource, params) => {
    const { json } = await httpClient(`${apiUrl}/${resource}/${params.id}`, {
      method: 'DELETE',
    });
    return {
      data: json,
    };
  },

  deleteMany: (resource, params) => {
    const url = `${apiUrl}/${resource}`;
    return httpClient(url, {
      method: 'DELETE',
      body: JSON.stringify(params.ids),
    }).then(({ json }) => ({
      data: json,
    }));
  },

  getMany: (resource, params) => {
    const url = `${apiUrl}/${resource}`;
    return httpClient(url).then(({ json }) => ({
      data: json.registros.filter(record => params.ids.includes(record.id)),
    }));
  },

  getManyReference: (resource, params) => {
    const url = `${apiUrl}/${resource}`;
    return httpClient(url).then(({ json }) => ({
      data: json.registros.filter(record => record[params.target] === params.id),
      total: json.registros.filter(record => record[params.target] === params.id).length,
    }));
  },
};