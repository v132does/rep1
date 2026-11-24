create or replace package it.PAE_MAN is

  -- Author  : AGUSTIN MEZA
  -- Created : 19/03/2008 08:38:43 a.m.
  -- Purpose : Manejo de Manuales
  
  -- Public function and procedure declarations
  function fu_buscar(ptexto in varchar2) return CLOB;
  
  function fu_orden(p_cod_manual in varchar2) return varchar2;
  
  function fu_obt_arbol(p_cod_manual in varchar2) return varchar2;
  
  function fu_obt_padres(p_cod_manual in varchar2) return varchar2;
  
  
end PAE_MAN;
/

