CREATE OR REPLACE FUNCTION IT.fug_es_servicio( p_nro_cuenta    GE_CUENTAS.NRO_CUENTA%TYPE,
                          p_cod_tra_padre GE_TRANSACCIONES.COD_TRANSACCION%TYPE,
                          p_cod_tra_comision ge_transacciones.cod_transaccion%type default null
                          ) RETURN VARCHAR2 IS
  vserv VARCHAR2(1) := 'N';
BEGIN
 if p_cod_tra_comision is not null then --para reversión de la remisión
    select 'S'
      into vserv
      from ge_cob_ser_parametros
     where nro_cuenta = p_nro_cuenta
       and cod_tra_comision = p_cod_tra_comision;
 else --para reversión del cobro
    select 'S'
      into vserv
      from ge_cob_ser_parametros
     where nro_cuenta = p_nro_cuenta
       and cod_transaccion = p_cod_tra_padre;
 end if;
 return vserv;
EXCEPTION
 when no_data_found then
   vserv := 'N';
   return vserv;
 when too_many_rows then
   vserv := 'S';
   return vserv;
 when others then
   RAISE_APPLICATION_ERROR( -20202, 'Buscar el servicio (FUG_ES_SERVICIO) ' || sqlerrm );
END;
/

