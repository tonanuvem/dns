import { fetchUtils } from 'react-admin';

const apiUrl = process.env.REACT_APP_API_URL || 'http://localhost:3000';

const httpClient = (url, options = {}) => {
  if (!options.headers) {
    options.headers = new Headers({ Accept: 'application/json' });
  }
  const token = localStorage.getItem('apiKey');
  options.headers.set('X-API-Key', token);
  return fetchUtils.fetchJson(url, options);
};

export const dataProvider = {
  getList: (resource, params) => {
    const url = `${apiUrl}/${resource}`;
    return httpClient(url).then(({ json }) => ({
      data: json.registros,
      total: json.registros.length,
    }));
  },

  getOne: (resource, params) => {
    const url = `${apiUrl}/${resource}/${params.id}`;
    return httpClient(url).then(({ json }) => ({
      data: json,
    }));
  },

  create: (resource, params) => {
    const url = `${apiUrl}/${resource}`;
    return httpClient(url, {
      method: 'POST',
      body: JSON.stringify(params.data),
    }).then(({ json }) => ({
      data: { ...params.data, id: json.id },
    }));
  },

  update: (resource, params) => {
    const url = `${apiUrl}/${resource}/${params.id}`;
    return httpClient(url, {
      method: 'PUT',
      body: JSON.stringify(params.data),
    }).then(({ json }) => ({
      data: json,
    }));
  },

  delete: (resource, params) => {
    const url = `${apiUrl}/${resource}/${params.id}`;
    return httpClient(url, {
      method: 'DELETE',
    }).then(({ json }) => ({
      data: json,
    }));
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