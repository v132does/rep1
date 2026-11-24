create or replace function it.fug_obt_cod_cau_bcp (p_cod_sub_causa      ge_causales_det.cod_sub_causa%type,
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

  v_cod_cau_bcp varchar2(10);
begin
  select d.cod_cau_bcp
    into v_cod_cau_bcp
    from ge_causales_det d
   where d.cod_sub_causa = p_cod_sub_causa
     and d.cod_causa = p_cod_cau_devolucion
     and rownum = 1;
  return(v_cod_cau_bcp);
exception
  when others then
    return '';
end fug_obt_cod_cau_bcp;
/
