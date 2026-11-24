create or replace procedure it.prw_pro_tra_bca_electronica(v_respuesta out clob, v_pedido in clob) is

  -- OMM 18/10/2010 Procedimiento q comunica a la base con el Socket JAVA.
  --v_respuesta clob;

  -- Funcion que procesa los pedidos realizados a traves de los Autoservicios, Autoconsultas,
  -- HomeBanking y Telefonos ceculares (WAP)
  --v_pedido          varchar2(4000) := ltrim(rtrim(p_pedido1));
 -- v_pedido          clob := para--||rtrim(p_pedido2)||rtrim(p_pedido3);

  --v_parametros      varchar2(4000);
  v_parametros      clob;
  --
  --v_sentencia     varchar2(4000);  -- sentencia dinamica a ejecutar
  v_sentencia      long;
  -- defino por defecto el modulo a utilizar
  v_cod_modulo    number(3) := 9; -- modulo de caja
  -- Datos de salida
  v_msj_respuesta clob := ''; -- sin errores
  v_lugar         varchar2(200);
  -------------------------------------------------------------------------------
  --           CODIGOS DE RESPUESTAS POSIBLES
  --           COD  RESPUESTA
  --           000  Aprobado
  --           -01  Cuenta o tarjeta inexistente
  --           -02  Cuenta o tarjeta duplicada
  --           -03  Clave(PIN) invalida
  --           -04  Clave(PIN) inexistente
  --           -05  Saldo insuficiente
  --           -06  Sistema en cierre
  --           -07  Cuenta o tarjeta sin movimientos
  --           -08  Sin autorizacion para realizar la operacion
  --           -09  Transaccion invalida
  --           -10  Transaccion prohibida
  --           -11  Cantidad invalida
  --           -12  Cuenta o tarjeta cancelada
  --           -13  Cuenta o tarjeta bloqueada
  --           -14  Cuenta o tarjeta invalida
  --           -15  Pago procesado en forma posterior
  --           -18  Clave Bloqueada
  --           -20  Autoservicio no habilitado
  --           -99  Otro error
  --            OJO! Hay otros errores definidos en la Cabecera de paw_bce.
  --------------------------------------------------------------------------------
  procedure lp_reg_operacion(v_pedido in varchar2, v_respuesta in varchar2) is
    PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
  begin
     insert into bw_log_bca_electronica
       (mensaje, respuesta)
     values
       (v_pedido, v_respuesta);
     commit;
  exception
     when others then null;
  end;
  --
begin
  pre_cam_for_numerico('.,');
  -- inicializo codigo de respuesta
  paw_bce.v_cod_respuesta := '000';
  -- Inicializacion de la aplicacion y el modulo
  BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=v_cod_modulo; END;
  -- SI EL SERVIDOR ES EN C, DESMARCAR LA SENTENCIA DE ABAJO
  -- Le saco los dos ultimos caracteres al pedido (son basura)
  -- v_pedido := substr(v_pedido,1,length(v_pedido)-2);
  -- Formato del pedido:
  v_lugar := 'Tomando nro de terminal, nro de operacion y transaccion';
  paw_bce.v_nro_terminal  := substr(v_pedido,1,3);
  paw_bce.v_nro_operacion := substr(v_pedido,4,10);
  paw_bce.v_cod_operacion := substr(v_pedido,14,3);
  v_parametros    := substr(v_pedido,17); -- resto es parametro

  -- inicializo la respuesta con el nro de terminal y nro de operacion
  v_respuesta := paw_bce.v_nro_terminal||paw_bce.v_nro_operacion;
  -- valido el nro de terminal en Cajas
  v_lugar := 'Validando la Caja';
  paw_bce.pr_val_caja;
  v_lugar := 'Procesando la transaccion '||paw_bce.v_cod_operacion;
  if paw_bce.v_cod_respuesta =  '000' then
     if paw_bce.v_cod_operacion = '021' then -- movimientos invoca directo porque puede ser muy extenso
        v_msj_respuesta := paw_bce.fu_pro_operacion_021(v_parametros);
     elsif paw_bce.v_cod_operacion = '022' then -- Reimpresion de comprobantes.
        v_msj_respuesta := paw_bce.fu_pro_operacion_022(v_parametros);
     elsif paw_bce.v_cod_operacion = '070' then -- pago de sueldos
        v_msj_respuesta := paw_bce.fu_pro_operacion_070(v_parametros);
     elsif paw_bce.v_cod_operacion = '075' then -- pago a proveedores
        v_msj_respuesta := paw_bce.fu_pro_operacion_075(v_parametros);
     elsif paw_bce.v_cod_operacion = '023' then -- autorizacion de operaciones
        v_msj_respuesta := paw_bce.fu_pro_operacion_023(v_parametros);
     elsif paw_bce.v_cod_operacion = '024' then -- consulta autorizacion de operaciones
        v_msj_respuesta := paw_bce.fu_pro_operacion_024(v_parametros);
     elsif paw_bce.v_cod_operacion = '025' then -- impresion de facturas
        v_msj_respuesta := paw_bce.fu_pro_operacion_025(v_parametros);
     elsif paw_bce.v_cod_operacion = '020' then -- consulta de saldos de operaciones
        v_msj_respuesta := paw_bce.fu_pro_operacion_020(v_parametros);
     elsif paw_bce.v_cod_operacion = '225' then -- consulta de histórico de pago a proveedores
        v_msj_respuesta := paw_bce.fu_pro_operacion_225(v_parametros);
     else
         -- es caja valida, se puede continuar
         v_sentencia := 'Begin '||
                          ' :r := paw_bce.fu_pro_operacion_'||paw_bce.v_cod_operacion||'('''||v_parametros||'''); '||
                        'End;';
         v_msj_respuesta :=  trim(sql_util.ejecute_funcion(v_sentencia));
        
     end if;
     if paw_bce.v_cod_respuesta <> '000' then
        -- no se termino bien la operacion, se hace rollback
        rollback;
     end if;
  end if;
  v_lugar := 'Armando la respuesta';
  -- armo la respuesta  con el formato
  v_respuesta := v_respuesta||paw_bce.v_cod_respuesta||v_msj_respuesta;
  -- envio la respuesta --
  lp_reg_operacion(substr(v_pedido,1,4000),substr(v_respuesta,1,4000));
  return;
exception
   when others then
       rollback; -- se hace rollback, porque hubo erro grave
       v_respuesta := (v_respuesta||'-99 '||sqlerrm||'-'||length(v_pedido)||'-'||v_lugar||'-'||paw_bce.v_lugar||length(v_msj_respuesta)||'-'||v_msj_respuesta); -- error
       --raise_application_error(-20006,sqlerrm);
end prw_pro_tra_bca_electronica;
/

