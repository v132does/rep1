create or replace function it.FUG_OBT_USU_SOL_PROMOTOR
  ( P_NRO_SOLICITUD IN VARCHAR2 )
  return varchar2 is
  v_cod_usu_promotor pr_solicitudes.cod_usu_promotor%type;
  v_campo varchar2(15);
begin
  v_campo := fug_obt_pardinamico('WOR_USU_PROM_OPERACION');
  -- Recupera el oficial del cliente
  if v_campo ='USU_INSERCION' then
   begin
     select usu_insercion
       into v_cod_usu_promotor
       from pr_solicitudes c
      where c.nro_solicitud = p_nro_solicitud;
   exception
      when no_data_found then
          select usu_insercion
            into v_cod_usu_promotor
            from cr_solicitudes c
           where c.nro_solicitud = p_nro_solicitud;
   end;
  else
    select cod_usu_promotor
      into v_cod_usu_promotor
      from pr_solicitudes c
     where c.nro_solicitud = p_nro_solicitud;
  end if;

  return v_cod_usu_promotor;
exception
  when no_data_found then
     return null;
  when others then
     raise_application_error(-20000,'FUG_OBT_USU_SOL_PROMOTOR'||sqlerrm);
end FUG_OBT_USU_SOL_PROMOTOR;
/

