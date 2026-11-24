create or replace function it.fug_obt_des_ser_digital -- Trae la descripcion de los cargos de Servicio Digital
   (p_mto_debito in ge_ext_cli_movimientos.mto_debito%type,
    p_nro_operacion in varchar2,
    p_fec_movimiento in date,
    p_hor_movimiento in varchar2,
    p_cod_modulo in number,
    p_cod_modalidad in number,
    p_cod_tra_padre in number,
    p_nro_secuencia in number)
    return varchar2 is  -- Devuelve desripcion de la transaccion
    Result varchar2(40);
    Var1 varchar2 (40);

begin
  -- Trae la descripcion para movimiento de Servicio Digital
    select case
    when (select a.COD_TRANSACCION from gv_movimientos a where a.nro_documento = p_nro_operacion
          and a.FECHA = p_fec_movimiento and a.HORA = p_hor_movimiento and a.MONTO = p_mto_debito
          and a.COD_TRA_PADRE = p_cod_tra_padre and a.NRO_SECUENCIA = p_nro_secuencia
          and rownum=1) = '9612' THEN
          'IVA S/SERVICIOS DIGITALES LEY 6380/19'
    when (select a.COD_TRANSACCION from gv_movimientos a where a.nro_documento = p_nro_operacion
          and a.FECHA = p_fec_movimiento and a.HORA = p_hor_movimiento and a.MONTO = p_mto_debito
          and a.COD_TRA_PADRE = p_cod_tra_padre and a.NRO_SECUENCIA = p_nro_secuencia
          and rownum=1) = '9611' THEN
          'INR S/SERVICIOS DIGITALES LEY 6380/19'
    when (select a.COD_TRANSACCION from gv_movimientos a where a.nro_documento = p_nro_operacion
          and a.FECHA = p_fec_movimiento and a.HORA = p_hor_movimiento and a.MONTO = p_mto_debito
          and a.COD_TRA_PADRE = p_cod_tra_padre and a.NRO_SECUENCIA = p_nro_secuencia
          and rownum=1) not in (9611,9612) THEN
       fug_obt_des_transaccion(p_cod_modulo,p_cod_modalidad,p_cod_tra_padre)
    END Valor
    INTO Var1 from dual;

 Result := Var1;
 return(Result);

exception
  when no_data_found then
     raise_application_error(-20000,'Error al consultar la operacion : '||p_nro_operacion||'-'||sqlerrm);
  when others then
     raise_application_error(-20000,'Error en fug_obt_des_ser_digital : '||p_nro_operacion||'-'||sqlerrm);
end fug_obt_des_ser_digital;
/

