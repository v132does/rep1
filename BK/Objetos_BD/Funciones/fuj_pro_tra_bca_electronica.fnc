create or replace function it.FUJ_PRO_TRA_BCA_ELECTRONICA(p_pedido in varchar2)
  return clob is
  v_respuesta clob;
  -- Funcion que procesa los pedidos realizados a traves de los Autoservicios, Autoconsultas,
  -- HomeBanking y Telefonos ceculares (WAP)
  v_pedido          varchar2(2000) := ltrim(rtrim(p_pedido));
  v_parametros      varchar2(4000);
  --
  v_sentencia     varchar2(2000);  -- sentencia dinamica a ejecutar
  -- defino por defecto el modulo a utilizar
  v_cod_modulo    number(3) := 9; -- modulo de caja
  -- Datos de salida
  v_msj_respuesta clob := ''; -- sin errores
  -------------------------------------------------------------------------------
  --           CODIGOS DE RESPUESTAS POSIBLES
  --           COD  RESPUESTA
  --           000	Aprobado
  --           -01	Cuenta o tarjeta inexistente
  --           -02	Cuenta o tarjeta duplicada
  --           -03	Clave(PIN) invalida
  --           -04	Clave(PIN) inexistente
  --           -05	Saldo insuficiente
  --           -06	Sistema en cierre
  --           -07	Cuenta o tarjeta sin movimientos
  --           -08	Sin autorización para realizar la operación
  --           -09	Transacción invalida
  --           -10	Transacción prohibida
  --           -11	Cantidad invalida
  --           -12	Cuenta o tarjeta cancelada
  --           -13	Cuenta o tarjeta bloqueada
  --           -14	Cuenta o tarjeta invalida
  --           -15	Pago procesado en forma posterior
  --           -18	Clave Bloqueada
  --           -20	Autoservicio no habilitado
  --           -99	Otro error
  --------------------------------------------------------------------------------
begin
  -- inicializo codigo de respuesta
  paj_bce.v_cod_respuesta := '000';
  -- Inicializacion de la aplicacion y el modulo
  BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=v_cod_modulo; END;
  -- SI EL SERVIDOR ES EN C, DESMARCAR LA SENTENCIA DE ABAJO
  -- Le saco los dos ultimos caracteres al pedido (son basura)
  -- v_pedido := substr(v_pedido,1,length(v_pedido)-2);
  -- Formato del pedido:
  paj_bce.v_nro_terminal  := substr(v_pedido,1,3);
  paj_bce.v_nro_operacion := substr(v_pedido,4,10);
  paj_bce.v_cod_operacion := substr(v_pedido,14,3);
  v_parametros    := substr(v_pedido,17); -- resto es parametro
  -- inicializo la respuesta con el nro de terminal y nro de operacion
  v_respuesta := paj_bce.v_nro_terminal||paj_bce.v_nro_operacion;
  -- valido el nro de terminal en Cajas
  paj_bce.pr_val_caja;
  if paj_bce.v_cod_respuesta =  '000' then
     if paj_bce.v_cod_operacion = '021' then -- movimientos invoca directo porque puede ser muy extenso
        v_msj_respuesta := paj_bce.fu_pro_operacion_021(v_parametros);
     else
         -- es caja valida, se puede continuar
         v_sentencia := 'Begin '||
                          ' :r := paj_bce.fu_pro_operacion_'||paj_bce.v_cod_operacion||'('''||v_parametros||'''); '||
                        'End;';
         v_msj_respuesta :=  trim(sql_util.ejecute_funcion(v_sentencia));
     end if;
     if paj_bce.v_cod_respuesta <> '000' then
        -- no se termino bien la operacion, se hace rollback
        rollback;
     end if;
  end if;
  -- armo la respuesta  con el formato
  v_respuesta := v_respuesta||paj_bce.v_cod_respuesta||v_msj_respuesta;
  -- envio la respuesta --
  return(v_respuesta);
exception
   when others then
       rollback; -- se hace rollback, porque hubo erro grave
       return (v_respuesta||'-99 '||sqlerrm); -- error
       --raise_application_error(-20006,sqlerrm);
end FUJ_PRO_TRA_BCA_ELECTRONICA;
/

