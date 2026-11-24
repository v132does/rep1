create or replace function it.FUP_OBT_MAD_ORI_FONDOS
          (p_ori_fondo pr_fondos.cod_ori_fondo%type)
  return varchar2 is
  v_modalidades pr_fondos.par_modalidad%TYPE;
begin
  begin
    select nvl(pfond.par_modalidad,'0')
    into   v_modalidades
    from   pr_fondos pfond
    where  pfond.cod_ori_fondo = p_ori_fondo;
  exception
    when no_data_found then
      v_modalidades := '0';
    when others then
      v_modalidades := '0';
  end;

  Return v_modalidades;

end FUP_OBT_MAD_ORI_FONDOS;
/

