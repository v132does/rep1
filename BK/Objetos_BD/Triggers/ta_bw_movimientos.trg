CREATE OR REPLACE TRIGGER IT.TA_BW_MOVIMIENTOS
 AFTER INSERT
  ON BW_MOVIMIENTOS
 FOR EACH ROW
DECLARE
v_nom_cliente   varchar2(50) ;
v_nom_ente      varchar2(50) ;
v_monto         varchar2(20) ;
v_respuesta     varchar2(80) ;
v_recipiente    varchar2(50) := trim(fug_obt_pardinamico('DIR_CORREO_SALARIOS')) ;

begin

    if :new.cod_respuesta <> '000' and :new.cod_tip_mensaje = '070' then
        v_nom_cliente := substr(FUE_OBT_NOM_PERSONA(:new.cod_per_principal),1,49) ;
        v_nom_ente    := substr(FUE_OBT_NOM_ENTE(:new.dato),1,49);
        v_monto       := to_char(:new.monto,'999G999G999G999D00');
        if :new.cod_respuesta = '-88' then
            v_respuesta   := 'Una o mas cuentas a acreditar tiene errores en la validaciòn';
        elsif :new.cod_respuesta = '-14' then
            v_respuesta   := 'Error en la cuenta de debito';
        elsif :new.cod_respuesta = '-02' then
            v_respuesta   := 'Error cuenta de debito duplicada (ente esta definido mas de una vez)';
        elsif :new.cod_respuesta = '-08' then
            v_respuesta   := 'Sin autorizacion - Ente no esta activo para operar en HB';
        elsif :new.cod_respuesta = '-11' then
            v_respuesta   := 'La cantidad de Empleados especificados no es igual a la cantidad levantada';
        elsif :new.cod_respuesta = '-22' then
            v_respuesta   := 'Total ingresado a debitar es distinto a la suma de todos los creditos.';
        end if ;

        it_mail.mail(fug_obt_dir_correo,
            v_recipiente,
            'Error en Salarios WEB - '||v_nom_cliente ,
            'Error en Pago de Sueldos ingresado por HomeBanking '|| chr(10) ||
            'Cliente   : ' || :new.cod_per_principal||' '||v_nom_cliente  || chr(10) ||
            'Cod. Ente : ' || :new.dato || chr(10) ||
            'Empresa   : ' || v_nom_ente|| chr(10) ||
            'Monto     : ' || v_monto || chr(10) ||
            'Moneda    : ' || :new.cod_moneda || chr(10) ||
            'Cantidad  : ' || :new.cantidad || chr(10) ||
            'Cta Debito: ' || :new.nro_cuenta || chr(10) ||
            'Msj. Error: ' || :new.cod_respuesta || ' '|| v_respuesta || chr(10) || chr(10) ||
            'Atentamente. '
            );
      end if ;
 EXCEPTION
  WHEN OTHERS THEN
   raise_application_error(-20000,'TA_BW_MOVIMIENTOS -'||sqlerrm);
end TA_BW_MOVIMIENTOS;
/

