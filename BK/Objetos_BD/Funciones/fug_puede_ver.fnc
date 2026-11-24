create or replace function it.fug_puede_ver (p_cod_persona in varchar2) return varchar2 is
  v_puede_ver varchar2(1) := 'N';
  v_oficial   varchar2(1) := 'N';
  v_promotor  varchar2(1) := 'N';
  v_cod_oficial  ba_usuarios.cod_usuario%type;
  v_cod_promotor ba_usuarios.cod_usuario%type;
  v_supervisor   ba_usuarios.cod_usuario%type;
  v_es_supervisor varchar2(1) := 'N';
  v_categoria     varchar2(4);
  v_cod_segmento  number(5);
begin
/*
  Begin
    Select oficial, promotor, categoria
      into v_oficial, v_promotor, v_categoria
      from ba_usuarios
     where cod_usuario = user;
  Exception
    When NO_DATA_FOUND Then
       return ('N'); -- retorna directamente NO
  End;
  */
  v_puede_ver := 'S';
  return(v_puede_ver);
end fug_puede_ver;
/

