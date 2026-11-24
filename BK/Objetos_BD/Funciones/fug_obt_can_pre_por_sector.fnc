create or replace function it.FUG_OBT_CAN_PRE_POR_SECTOR
  (P_COD_PERSONA IN VARCHAR2,                  --- Codigo de la persona
   P_COD_SECTOR  IN VARCHAR2 DEFAULT NULL )       --- sector del cliente
  return number is
  Result number;
begin
  -- Busca la cantidad de préstamos activos por sector de crédito
select count(*)
  into Result
  from pr_cta_prestamos p, ge_cta_clientes c, pr_sec_creditos s, ba_cod_referencias b
 where nvl( p.estado, 'X' ) <> 'N'
   and nvl( c.relacion, 'P' ) = 'P'
   and c.cod_persona = p_cod_persona
   and b.val_minimo = p_cod_sector
   and to_char( p.fec_inicio, 'MM/YYYY' ) = to_char( fue_obt_fec_calendar(1), 'MM/YYYY' )
   and b.dominio = 'COD_SEC_PADRE'
   and p.nro_cuenta = c.nro_cuenta
   and s.cod_sec_padre = b.val_minimo
   and s.cod_sec_credito = p.cod_sec_credito;

  return(Result);
exception
  when others then
     raise_application_error(-20000,'FUG_OBT_CAN_PRE_POR_SECTOR'||sqlerrm);
end FUG_OBT_CAN_PRE_POR_SECTOR;
/

