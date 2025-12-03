// src/axios.js
import axios from 'axios';

const instance = axios.create({
  baseURL: process.env.REACT_APP_API || '/api', // Use env variable or fallback to proxy
});

instance.interceptors.request.use((config) => {
  const token = localStorage.getItem('token');
  if (token) config.headers['Authorization'] = `Bearer ${token}`;
  return config;
});

export default instance;
