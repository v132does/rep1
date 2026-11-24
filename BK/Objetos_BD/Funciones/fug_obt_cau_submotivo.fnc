create or replace function fug_obt_cau_submotivo(p_cod_cau_bcp        it.ge_causales_det.cod_sub_causa%type,
                                                    p_cod_cau_devolucion cc_che_rechazados.cod_cau_devolucion%type)
  return varchar2 is

/*
-------------------------------------------------------------------------
AVISO IMPORTANTE: IT CONSULTORES S.A. es titular de todos los derechos
del Software IT GESTION FINANCIERA, incluyendo los derechos del autor
sobre dicho software y por tanto, propietario del citado software y de
cualquier modificación y/o copia del mismo. Por este motivo, este programa
del Software IT GESTIÓN FINANCIERA debe ser mantenido bajo una adecuada
seguridad, y asegurar con ello que no haya acceso a copias o utilización no
autorizada por IT CONSULTORES S.A. COPYRIGHT IT CONSULTORES S.A. 2017.
Todos los derechos reservados.
-------------------------------------------------------------------------
*/

  v_cod_causa varchar2(10);
begin
  select d.cod_sub_causa
    into v_cod_causa
    from ge_causales_det d
   where to_number(d.cod_cau_bcp) = to_number(p_cod_cau_bcp)
     and d.cod_causa = p_cod_cau_devolucion;
     --and rownum = 1;
  return(v_cod_causa);
exception
  when no_data_found then
    return null;
  when others then
    raise_application_error (-20000,'Error- Cau.Bcp: '||p_cod_cau_bcp||' Cau.Dev.: '||p_cod_cau_devolucion||'-'|| sqlerrm);
end fug_obt_cau_submotivo;
