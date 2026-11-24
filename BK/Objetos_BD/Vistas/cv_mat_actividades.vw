create or replace force view it.cv_mat_actividades as
select 'PEP`s (Personas Expuestas Políticamente)' Descripcion, 'PEP' codigo
  from dual
  union all
  select 'Abogado', 'ABO' from dual
  union all
  select 'Contador', 'CON' from dual
  union all
  select 'Escribano', 'ESC' from dual
  union all
  select 'Funcionario Público en Entidad Pública', 'FPEP' from dual
  union all
  select 'Comerciante o Empresa de Metales Preciosos', 'CMP' from dual
  union all
  select 'Comerciante o Empresa de Obras de Arte', 'COA' from dual
  union all
  select 'Comerciante o Empresa de Antigüedades', 'ANT' from dual
  union all
  select 'Comerciante o Empresa de Numismática', 'NUM' from dual
  union all
  select 'Comerciante o Empresa de Filatelia', 'FIL' from dual
  union all
  select 'Propietarios o Empresa de Juegos de Azar', 'JUE' from dual
  union all
  select 'Propietarios de/o Empresa Inmobiliaria', 'INM' from dual
  union all
  select 'Directivos de/o Fundaciones', 'FUD' from dual
  union all
  select 'Propietarios o Empresa de Casas de Empeños', 'EMP' from dual
  union all
  select 'Directivos o Empresa de Casas de Cambios', 'CAM' from dual
  union all
  select 'Directivos o Empresa de Compañías de Seguros', 'SEG' from dual
  union all
  select 'Directivos de/o Entidades Financieras', 'FIN' from dual
  union all
  select 'Directivos de/o Empresas de Caridad', 'CAR' from dual
  union all
  select 'Propietarios o Empresa de Casas de Ventas de Armas', 'ARM' from dual
  union all
  select 'Directivos de/o ONG´s', 'ONG' from dual
  union all
  select 'Administradores de Fondos Mutuos', 'FMU' from dual
  union all
  select 'Jubilados', 'JUB' from dual
  union all
  select 'Importación/Exportación', 'IEX' from dual
  union all
  select 'Demás Actividades', 'OTR' from dual;

