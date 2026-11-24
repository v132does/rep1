CREATE OR REPLACE FUNCTION IT.FUJ_VAL_TRANSACCION_358
 (P_NRO_OPERACION IN VARCHAR2
 ,P_NRO_CAJA IN VARCHAR2
 ,P_NRO_CUENTA IN VARCHAR2
 )
 RETURN long
 IS
begin
    declare
  -- Datos de la transaccion
  v_cod_modulo         number(3) := 9;              -- modulo Caja
  v_cod_modalidad      number(3) := 91;             -- modalidad Caja
  v_cod_transaccion    number(4) := 358;            -- cod de transaccion
  v_cod_usuario        varchar2(10) := upper(user); --usuario
  -- Datos de la caja
  v_fec_actual         date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_hora               varchar2(8);
  v_cod_oficina        number(3);         -- Codigo de oficina
  v_estado             number(1);         -- estado de la caja
  v_fec_caja           date;              -- fecha de la caja
  v_sal_actual         number(18,2);      -- saldo actual de la caja en efectivo
  v_sal_cheques        number(18,2);      -- saldo actual de la caja en cheques
  -- Datos de la cuenta de préstamo
  v_denominacion       varchar2(100);     -- Nombre de la cuenta
  v_mto_desembolsar    number(18,2);      -- Monto a desembolsar (despliega)

  v_tip_cuenta         number(3);         -- modalidad cta
  v_cod_moneda         varchar2(3);       -- moneda de la cta
  v_est_cuenta         varchar2(1);       -- estado de la cuenta

  -- Datos de salida
  v_msj_salida    long;--varchar2(8000);        -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000'; -- sin errores
  v_msj_respuesta varchar2(4000) := 'OK'; -- sin errores

  -- Datos de campos a devolver
  v_can_campos    number(3)      := 2;   -- cantidad de campos
  v_det_campos    varchar2(8000) :=       -- valores devueltos por defecto
           '[' || 'DES_CUENTA' ||'~ ]' ||
           '[' || 'TOT_DESEMBOLSO' ||'~ ]' ;

  v_cod_tran_pend  number(4);    --- transaccion operacion pend.(efect 840 - cheq 607)
  v_monto_efectivo number(18,2) :=0; --- importe pagado operacion pendiente efectivo
  v_monto_cheque   number(18,2) :=0; --- importe pagado operacion pendiente cheque

  -- Contenedor de la lista de valores a devolver
  v_val_posibles  varchar2(3000) := null;

-------------------------PROCESO PRINCIPAL-------------------------
Begin
 -- Inicializacion de la aplicacion y el modulo
 Begin PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=v_cod_modulo; End;

 if p_nro_cuenta is null then  -- valido la cuenta
--    v_cod_respuesta := '002'; -- error
--    v_msj_respuesta := 'ERROR: Ingrese la Cuenta del cliente.';

       -- Obtengo el select de la lista de valores para el documento
   v_val_posibles  := fuj_obt_val_posibles(v_cod_transaccion,'NRO_CUENTA');

   if v_cod_respuesta = '000' then
     v_det_campos := v_det_campos ||
                      '[' ||
                      'NRO_CUENTA~X~'||
                      fuj_pro_val_posibles(v_val_posibles) ||
                      ']';
     v_can_campos := v_can_campos + 1;
   end if;

 else
    -- obtengo datos de la cuenta  --
    begin
      select denominacion, cod_modulo, cod_moneda
        into v_denominacion, v_tip_cuenta, v_cod_moneda
        from ge_cuentas a
       where a.nro_cuenta = p_nro_cuenta;


       -- Obtengo los datos de la caja --
      prj_obt_datos_caja(p_nro_caja,
                       v_cod_moneda,
                       v_cod_oficina,
                       v_fec_caja,
                       v_estado,
                       v_sal_actual,
                       v_sal_cheques);
      if v_estado = -1 then
        v_cod_respuesta := '003'; -- error, no existe registro de caja
        v_msj_respuesta := 'Caja inexistente!!';
      elsif v_estado in (0,2) then
        v_cod_respuesta := '004'; -- error
        v_msj_respuesta := 'Realice la Apertura de Caja previamente';
      elsif v_fec_caja <> v_fec_actual then
        v_cod_respuesta := '005'; -- error
        v_msj_respuesta := 'Caja no fue habilitada el dia de hoy';
      end if;

      if v_tip_cuenta <> 6 then
        v_cod_respuesta := '006';
        v_msj_respuesta := 'ERROR: Tipo de cuenta no es de Préstamos ';
      else
        -- AQUI LA VALIDACION DE SI ES PARA RETOMAR EN CAJA
        prj_ver_pen_caja(p_nro_cuenta,
                         v_cod_transaccion,
                         v_fec_actual,
                         v_cod_usuario,
                         v_hora,
                         v_cod_tran_pend,
                         v_cod_respuesta,
                         v_msj_respuesta);
       if   v_cod_respuesta = '000' then  ---- no hay pendientes
         v_cod_respuesta := '007';
         v_msj_respuesta := 'ERROR: No hay desembolso pendiente para esta cta.';
       else
         v_cod_respuesta := '000';
         begin
          select sum(nvl(monto,0)) into v_mto_desembolsar from
            ge_movimientos where
             hora          = v_hora and
             fecha         = v_fec_actual and
             cod_tra_padre = v_cod_transaccion and
             cod_modulo    = 6 and --- Para que no tome lo de ahorros
             estado        = 'J';
         exception
            when no_data_found then
               v_cod_respuesta := '008';
               v_msj_respuesta := 'ERROR: No encuentra desembolso pendiente para esta cta.'||sqlerrm;
            when others then
               v_cod_respuesta := '009';
               v_msj_respuesta := 'ERROR: al buscar mov.desembolso pendiente.'||sqlerrm;
         end;

       end if;

         v_det_campos :=
           '[' || 'DES_CUENTA' ||'~'||v_denominacion|| ']' ||
           '[' || 'COD_MONEDA' ||'~'||v_cod_moneda|| ']' ||
           '[' || 'TOT_DESEMBOLSO' ||'~'||ltrim(to_char(v_mto_desembolsar))|| ']' ;
      end if;

      exception
       when no_data_found then
        v_cod_respuesta := '010';
        v_msj_respuesta := 'Nro de cuenta no existe!';
       when others then
        v_cod_respuesta := '011';
        v_msj_respuesta := sqlerrm;
      end;

  end if;
  v_msj_salida := p_nro_operacion||'~'||
                  v_cod_respuesta||'~'||
                  nvl(v_msj_respuesta,'OK')||'~'||
                  ltrim(to_char(v_can_campos,'000'))||'~'||
                  v_det_campos;
  return(v_msj_salida);
end;
end;
/

