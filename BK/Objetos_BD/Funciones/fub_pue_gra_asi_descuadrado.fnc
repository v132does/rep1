create or replace function it.FUB_PUE_GRA_ASI_DESCUADRADO
            (P_COD_USUARIO     IN BA_USU_ROLES.COD_USUARIO%TYPE)
     return varchar2 is
  v_puede varchar2(1);
begin
 begin
    Select 'S'
     into v_puede
     from ba_usu_roles a
     where a.cod_usuario =  p_cod_usuario
     and   a.cod_rol     = 'GRA_ASI_DESCUADRADO';
  exception
     when no_data_found then
      v_puede := 'N';
     when too_many_rows then
      v_puede := 'S';
     when others then
      v_puede := 'N';
  end;
return(v_puede);
end;
/

