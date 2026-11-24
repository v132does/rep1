create or replace procedure it.PRG_PRO_INF_ECO_AUXILIAR(P_NRO_INF_CREDITO   in number
                                                    ,P_SUE_FIJO          out varchar2
                                                    ,P_SUE_VARIABLE      out varchar2
                                                    ,P_ING_INDEPENDIENTE out varchar2
                                                    ,P_ING_VENTA         out varchar2
                                                    ,P_ALQ_COBRADO       out varchar2
                                                    ,P_INT_AHORRO        out varchar2
                                                    ,P_REN_ACCION        out varchar2
                                                    ,P_JUB_PENCION       out varchar2
                                                    ,P_GAS_FAMILIAR      out varchar2
                                                    ,P_CUO_CONSUMO       out varchar2
                                                    ,P_CUO_TARJETA       out varchar2
                                                    ,P_CUO_HIPOTECA      out varchar2
                                                    ,P_NUE_CUOTA         out varchar2
                                                    ,P_ALQ_PAGADO        out varchar2
                                                    ,P_OTR_CUOTA         out varchar2
                                                    ,P_TOTAL_A           out varchar2
                                                    ,P_TOTAL_B           out varchar2
                                                    ,P_ING_MEN_EGRESOS   out varchar2
                                                    ,P_TOT_CUO_INGRESOS  out varchar2
                                                    ,P_CUO_SOL_INGRESOS  out varchar2
                                                     
                                                     ) is

   V_INI_POS   number := 0;
   V_FIN_POS   number := 0;
   V_CAN_TEXTO number := 0;
   V_VAL_TEXTO varchar2(4000) := null;
   -- DYDMR-6529
   V_LUGAR varchar2(100) := null;
   --
   V_INF_ECO_FIN_AUX clob;
begin
   /*se obtiene una sola vez el valor clob de la información económica auxiliar*/
   begin
      select INF_ECO_FIN_AUX
        into V_INF_ECO_FIN_AUX
        from GE_INF_CREDITOS
       where NRO_INF_CREDITO = P_NRO_INF_CREDITO;
   exception
      when others then
         RAISE_APPLICATION_ERROR(-20000, 'error al buscar dato inf eco aux: ' || sqlerrm);
   end;
   if V_INF_ECO_FIN_AUX is not null then
      PRE_CAM_FOR_NUMERICO(',.'); --DYDMR-9576 - Se ponen todos los campos como numérico y se pasa por nueva función fug_obt_tex_numero.
   
      /*se copia los datos del bloque :INF_ECO_FINANCIERA*/
      /*P_SUE_FIJO := :INF_ECO_FINANCIERA.SUE_FIJO;
      P_SUE_VARIABLE := :INF_ECO_FINANCIERA.SUE_VARIABLE;
      P_ING_INDEPENDIENTE := :INF_ECO_FINANCIERA.ING_INDEPENDIENTE;
      P_ING_VENTA := :INF_ECO_FINANCIERA.ING_VENTA;
      P_ALQ_COBRADO := :INF_ECO_FINANCIERA.ALQ_COBRADO;
      P_INT_AHORRO := :INF_ECO_FINANCIERA.INT_AHORRO;
      P_REN_ACCION := :INF_ECO_FINANCIERA.REN_ACCION;
      P_JUB_PENCION := :INF_ECO_FINANCIERA.JUB_PENCION;
      P_GAS_FAMILIAR := :INF_ECO_FINANCIERA.GAS_FAMILIAR;
      P_CUO_CONSUMO := :INF_ECO_FINANCIERA.CUO_CONSUMO;
      P_CUO_TARJETA := :INF_ECO_FINANCIERA.CUO_TARJETA;
      P_CUO_HIPOTECA := :INF_ECO_FINANCIERA.CUO_HIPOTECA;
      P_NUE_CUOTA := :INF_ECO_FINANCIERA.NUE_CUOTA;
      P_ALQ_PAGADO := :INF_ECO_FINANCIERA.ALQ_PAGADO;
      P_OTR_CUOTA := :INF_ECO_FINANCIERA.OTR_CUOTA;
      P_TOTAL_A := :INF_ECO_FINANCIERA.TOTAL_A;
      P_TOTAL_B := :INF_ECO_FINANCIERA.TOTAL_B;
      P_ING_MEN_EGRESOS := :INF_ECO_FINANCIERA.ING_MEN_EGRESOS;
      P_TOT_CUO_INGRESOS := :INF_ECO_FINANCIERA.TOT_CUO_INGRESOS;
      P_CUO_SOL_INGRESOS := :INF_ECO_FINANCIERA.CUO_SOL_INGRESOS;*/
   
      --Sueldo Fijo
      V_LUGAR := '016.001-PP_DES_INF_ECO_FINANCIERA';
      select TO_NUMBER(DBMS_LOB.INSTR(V_INF_ECO_FIN_AUX, '~sue_fijo<i:') +
                       LENGTH('~sue_fijo<i:'))
        into V_INI_POS
        from DUAL;
      V_LUGAR := '016.002-PP_DES_INF_ECO_FINANCIERA';
      select DBMS_LOB.INSTR(V_INF_ECO_FIN_AUX, ':f>', (V_INI_POS), 1)
        into V_FIN_POS
        from DUAL;
      V_LUGAR     := '016.003-PP_DES_INF_ECO_FINANCIERA';
      V_CAN_TEXTO := NVL(V_FIN_POS, 0) - NVL(V_INI_POS, 0);
      V_LUGAR     := '016.004-PP_DES_INF_ECO_FINANCIERA';
      select replace(DBMS_LOB.SUBSTR(V_INF_ECO_FIN_AUX, V_CAN_TEXTO, V_INI_POS),
                     CHR(44),
                     CHR(46)) --DYDMR-3071 - Sergio Servín 14-06-2016 11:21 AM
        into V_VAL_TEXTO
        from GE_INF_CREDITOS
       where NRO_INF_CREDITO = P_NRO_INF_CREDITO;
      V_LUGAR     := '016.005-PP_DES_INF_ECO_FINANCIERA';
      P_SUE_FIJO  := FUG_OBT_TEX_NUMERO(V_VAL_TEXTO);
      V_LUGAR     := '016.006-PP_DES_INF_ECO_FINANCIERA';
      V_INI_POS   := 0;
      V_FIN_POS   := 0;
      V_CAN_TEXTO := 0;
      V_VAL_TEXTO := null;
      --Sueldo Variable
      V_LUGAR := '016.007-PP_DES_INF_ECO_FINANCIERA';
      select TO_NUMBER(DBMS_LOB.INSTR(V_INF_ECO_FIN_AUX, '~sue_variable<i:') +
                       LENGTH('~sue_variable<i:'))
        into V_INI_POS
        from DUAL;
      V_LUGAR := '016.008-PP_DES_INF_ECO_FINANCIERA';
      select DBMS_LOB.INSTR(V_INF_ECO_FIN_AUX, ':f>', (V_INI_POS), 1)
        into V_FIN_POS
        from DUAL;
      V_LUGAR     := '016.009-PP_DES_INF_ECO_FINANCIERA';
      V_CAN_TEXTO := NVL(V_FIN_POS, 0) - NVL(V_INI_POS, 0);
      V_LUGAR     := '016.010-PP_DES_INF_ECO_FINANCIERA';
      select replace(DBMS_LOB.SUBSTR(V_INF_ECO_FIN_AUX, V_CAN_TEXTO, V_INI_POS),
                     CHR(44),
                     CHR(46)) --DYDMR-3071 - Sergio Servín 14-06-2016 11:21 AM 
        into V_VAL_TEXTO
        from DUAL;
      V_LUGAR        := '016.011-PP_DES_INF_ECO_FINANCIERA';
      P_SUE_VARIABLE := FUG_OBT_TEX_NUMERO(V_VAL_TEXTO);
      V_LUGAR        := '016.012-PP_DES_INF_ECO_FINANCIERA';
      V_INI_POS      := 0;
      V_FIN_POS      := 0;
      V_CAN_TEXTO    := 0;
      V_VAL_TEXTO    := null;
      --Ingreso Independiente
      V_LUGAR := '016.013-PP_DES_INF_ECO_FINANCIERA';
      select TO_NUMBER(DBMS_LOB.INSTR(V_INF_ECO_FIN_AUX, '~ing_independiente<i:') +
                       LENGTH('~ing_independiente<i:'))
        into V_INI_POS
        from DUAL;
      V_LUGAR := '016.014-PP_DES_INF_ECO_FINANCIERA';
      select DBMS_LOB.INSTR(V_INF_ECO_FIN_AUX, ':f>', (V_INI_POS), 1)
        into V_FIN_POS
        from DUAL;
      V_LUGAR     := '016.015-PP_DES_INF_ECO_FINANCIERA';
      V_CAN_TEXTO := NVL(V_FIN_POS, 0) - NVL(V_INI_POS, 0);
      V_LUGAR     := '016.016-PP_DES_INF_ECO_FINANCIERA';
      select replace(DBMS_LOB.SUBSTR(V_INF_ECO_FIN_AUX, V_CAN_TEXTO, V_INI_POS),
                     CHR(44),
                     CHR(46)) --DYDMR-3071 - Sergio Servín 14-06-2016 11:21 AM 
        into V_VAL_TEXTO
        from DUAL;
      V_LUGAR             := '016.017-PP_DES_INF_ECO_FINANCIERA';
      P_ING_INDEPENDIENTE := FUG_OBT_TEX_NUMERO(V_VAL_TEXTO);
      V_LUGAR             := '016.018-PP_DES_INF_ECO_FINANCIERA';
      V_INI_POS           := 0;
      V_FIN_POS           := 0;
      V_CAN_TEXTO         := 0;
      V_VAL_TEXTO         := null;
      --Ingreso Venta
      V_LUGAR := '016.019-PP_DES_INF_ECO_FINANCIERA';
      select TO_NUMBER(DBMS_LOB.INSTR(V_INF_ECO_FIN_AUX, '~ing_venta<i:') +
                       LENGTH('~ing_venta<i:'))
        into V_INI_POS
        from DUAL;
      V_LUGAR := '016.020-PP_DES_INF_ECO_FINANCIERA';
      select DBMS_LOB.INSTR(V_INF_ECO_FIN_AUX, ':f>', (V_INI_POS), 1)
        into V_FIN_POS
        from DUAL;
      V_LUGAR     := '016.021-PP_DES_INF_ECO_FINANCIERA';
      V_CAN_TEXTO := NVL(V_FIN_POS, 0) - NVL(V_INI_POS, 0);
      V_LUGAR     := '016.022-PP_DES_INF_ECO_FINANCIERA';
      select replace(DBMS_LOB.SUBSTR(V_INF_ECO_FIN_AUX, V_CAN_TEXTO, V_INI_POS),
                     CHR(44),
                     CHR(46)) --DYDMR-3071 - Sergio Servín 14-06-2016 11:21 AM 
        into V_VAL_TEXTO
        from DUAL;
      V_LUGAR     := '016.023-PP_DES_INF_ECO_FINANCIERA';
      P_ING_VENTA := FUG_OBT_TEX_NUMERO(V_VAL_TEXTO);
      V_LUGAR     := '016.024-PP_DES_INF_ECO_FINANCIERA';
      V_INI_POS   := 0;
      V_FIN_POS   := 0;
      V_CAN_TEXTO := 0;
      V_VAL_TEXTO := null;
      --Alquileres Cobrados
      V_LUGAR := '016.025-PP_DES_INF_ECO_FINANCIERA';
      select TO_NUMBER(DBMS_LOB.INSTR(V_INF_ECO_FIN_AUX, '~alq_cobrado<i:') +
                       LENGTH('~alq_cobrado<i:'))
        into V_INI_POS
        from DUAL;
      V_LUGAR := '016.026-PP_DES_INF_ECO_FINANCIERA';
      select DBMS_LOB.INSTR(V_INF_ECO_FIN_AUX, ':f>', (V_INI_POS), 1)
        into V_FIN_POS
        from DUAL;
      V_LUGAR     := '016.027-PP_DES_INF_ECO_FINANCIERA';
      V_CAN_TEXTO := NVL(V_FIN_POS, 0) - NVL(V_INI_POS, 0);
      V_LUGAR     := '016.028-PP_DES_INF_ECO_FINANCIERA';
      select replace(DBMS_LOB.SUBSTR(V_INF_ECO_FIN_AUX, V_CAN_TEXTO, V_INI_POS),
                     CHR(44),
                     CHR(46)) --DYDMR-3071 - Sergio Servín 14-06-2016 11:21 AM 
        into V_VAL_TEXTO
        from DUAL;
     
      V_LUGAR       := '016.029-PP_DES_INF_ECO_FINANCIERA';
      P_ALQ_COBRADO := FUG_OBT_TEX_NUMERO(V_VAL_TEXTO);
      V_LUGAR       := '016.030-PP_DES_INF_ECO_FINANCIERA';
      V_INI_POS     := 0;
      V_FIN_POS     := 0;
      V_CAN_TEXTO   := 0;
      V_VAL_TEXTO   := null;
      --Intereses por Ahorros
      V_LUGAR := '016.031-PP_DES_INF_ECO_FINANCIERA';
      select TO_NUMBER(DBMS_LOB.INSTR(V_INF_ECO_FIN_AUX, '~int_ahorro<i:') +
                       LENGTH('~int_ahorro<i:'))
        into V_INI_POS
        from DUAL;
      V_LUGAR := '016.032-PP_DES_INF_ECO_FINANCIERA';
      select DBMS_LOB.INSTR(V_INF_ECO_FIN_AUX, ':f>', (V_INI_POS), 1)
        into V_FIN_POS
        from DUAL;
      V_LUGAR     := '016.033-PP_DES_INF_ECO_FINANCIERA';
      V_CAN_TEXTO := NVL(V_FIN_POS, 0) - NVL(V_INI_POS, 0);
      V_LUGAR     := '016.034-PP_DES_INF_ECO_FINANCIERA';
      select replace(DBMS_LOB.SUBSTR(V_INF_ECO_FIN_AUX, V_CAN_TEXTO, V_INI_POS),
                     CHR(44),
                     CHR(46)) --DYDMR-3071 - Sergio Servín 14-06-2016 11:21 AM 
        into V_VAL_TEXTO
        from DUAL;
      V_LUGAR      := '016.035-PP_DES_INF_ECO_FINANCIERA';
      P_INT_AHORRO := FUG_OBT_TEX_NUMERO(V_VAL_TEXTO);
      V_LUGAR      := '016.036-PP_DES_INF_ECO_FINANCIERA';
      V_INI_POS    := 0;
      V_FIN_POS    := 0;
      V_CAN_TEXTO  := 0;
      V_VAL_TEXTO  := null;
      --Renta por Acciones
      V_LUGAR := '016.037-PP_DES_INF_ECO_FINANCIERA';
      select TO_NUMBER(DBMS_LOB.INSTR(V_INF_ECO_FIN_AUX, '~ren_accion<i:') +
                       LENGTH('~ren_accion<i:'))
        into V_INI_POS
        from DUAL;
      V_LUGAR := '016.038-PP_DES_INF_ECO_FINANCIERA';
      select DBMS_LOB.INSTR(V_INF_ECO_FIN_AUX, ':f>', (V_INI_POS), 1)
        into V_FIN_POS
        from DUAL;
      V_LUGAR     := '016.039-PP_DES_INF_ECO_FINANCIERA';
      V_CAN_TEXTO := NVL(V_FIN_POS, 0) - NVL(V_INI_POS, 0);
      V_LUGAR     := '016.040-PP_DES_INF_ECO_FINANCIERA';
      select replace(DBMS_LOB.SUBSTR(V_INF_ECO_FIN_AUX, V_CAN_TEXTO, V_INI_POS),
                     CHR(44),
                     CHR(46)) --DYDMR-3071 - Sergio Servín 14-06-2016 11:21 AM  
        into V_VAL_TEXTO
        from DUAL;
      V_LUGAR      := '016.041-PP_DES_INF_ECO_FINANCIERA';
      P_REN_ACCION := FUG_OBT_TEX_NUMERO(V_VAL_TEXTO);
      V_LUGAR      := '016.042-PP_DES_INF_ECO_FINANCIERA';
      V_INI_POS    := 0;
      V_FIN_POS    := 0;
      V_CAN_TEXTO  := 0;
      V_VAL_TEXTO  := null;
      --Jubilacion y Pension
      V_LUGAR := '016.043-PP_DES_INF_ECO_FINANCIERA';
      select TO_NUMBER(DBMS_LOB.INSTR(V_INF_ECO_FIN_AUX, '~jub_pencion<i:') +
                       LENGTH('~jub_pencion<i:'))
        into V_INI_POS
        from DUAL;
      V_LUGAR := '016.044-PP_DES_INF_ECO_FINANCIERA';
      select DBMS_LOB.INSTR(V_INF_ECO_FIN_AUX, ':f>', (V_INI_POS), 1)
        into V_FIN_POS
        from DUAL;
      V_LUGAR     := '016.045-PP_DES_INF_ECO_FINANCIERA';
      V_CAN_TEXTO := NVL(V_FIN_POS, 0) - NVL(V_INI_POS, 0);
      V_LUGAR     := '016.046-PP_DES_INF_ECO_FINANCIERA';
      select replace(DBMS_LOB.SUBSTR(V_INF_ECO_FIN_AUX, V_CAN_TEXTO, V_INI_POS),
                     CHR(44),
                     CHR(46)) --DYDMR-3071 - Sergio Servín 14-06-2016 11:21 AM  
        into V_VAL_TEXTO
        from DUAL;
      V_LUGAR       := '016.047-PP_DES_INF_ECO_FINANCIERA';
      P_JUB_PENCION := FUG_OBT_TEX_NUMERO(V_VAL_TEXTO);
      V_LUGAR       := '016.048-PP_DES_INF_ECO_FINANCIERA';
      V_INI_POS     := 0;
      V_FIN_POS     := 0;
      V_CAN_TEXTO   := 0;
      V_VAL_TEXTO   := null;
      --Gastos Familiares
      V_LUGAR := '016.049-PP_DES_INF_ECO_FINANCIERA';
      select TO_NUMBER(DBMS_LOB.INSTR(V_INF_ECO_FIN_AUX, '~gas_familiar<i:') +
                       LENGTH('~gas_familiar<i:'))
        into V_INI_POS
        from DUAL;
      V_LUGAR := '016.050-PP_DES_INF_ECO_FINANCIERA';
      select DBMS_LOB.INSTR(V_INF_ECO_FIN_AUX, ':f>', (V_INI_POS), 1)
        into V_FIN_POS
        from DUAL;
      V_LUGAR     := '016.051-PP_DES_INF_ECO_FINANCIERA';
      V_CAN_TEXTO := NVL(V_FIN_POS, 0) - NVL(V_INI_POS, 0);
      V_LUGAR     := '016.052-PP_DES_INF_ECO_FINANCIERA';
      select replace(DBMS_LOB.SUBSTR(V_INF_ECO_FIN_AUX, V_CAN_TEXTO, V_INI_POS),
                     CHR(44),
                     CHR(46)) --DYDMR-3071 - Sergio Servín 14-06-2016 11:21 AM 
        into V_VAL_TEXTO
        from DUAL;
      V_LUGAR        := '016.053-PP_DES_INF_ECO_FINANCIERA';
      P_GAS_FAMILIAR := FUG_OBT_TEX_NUMERO(V_VAL_TEXTO);
      V_LUGAR        := '016.054-PP_DES_INF_ECO_FINANCIERA';
      V_INI_POS      := 0;
      V_FIN_POS      := 0;
      V_CAN_TEXTO    := 0;
      V_VAL_TEXTO    := null;
      --Cuota Consumo
      V_LUGAR := '016.055-PP_DES_INF_ECO_FINANCIERA';
      select TO_NUMBER(DBMS_LOB.INSTR(V_INF_ECO_FIN_AUX, '~cuo_consumo<i:') +
                       LENGTH('~cuo_consumo<i:'))
        into V_INI_POS
        from DUAL;
      V_LUGAR := '016.056-PP_DES_INF_ECO_FINANCIERA';
      select DBMS_LOB.INSTR(V_INF_ECO_FIN_AUX, ':f>', (V_INI_POS), 1)
        into V_FIN_POS
        from DUAL;
      V_LUGAR     := '016.057-PP_DES_INF_ECO_FINANCIERA';
      V_CAN_TEXTO := NVL(V_FIN_POS, 0) - NVL(V_INI_POS, 0);
      V_LUGAR     := '016.058-PP_DES_INF_ECO_FINANCIERA';
      select replace(DBMS_LOB.SUBSTR(V_INF_ECO_FIN_AUX, V_CAN_TEXTO, V_INI_POS),
                     CHR(44),
                     CHR(46)) --DYDMR-3071 - Sergio Servín 14-06-2016 11:21 AM 
        into V_VAL_TEXTO
        from DUAL;
      V_LUGAR       := '016.059-PP_DES_INF_ECO_FINANCIERA';
      P_CUO_CONSUMO := FUG_OBT_TEX_NUMERO(V_VAL_TEXTO);
      V_LUGAR       := '016.060-PP_DES_INF_ECO_FINANCIERA';
      V_INI_POS     := 0;
      V_FIN_POS     := 0;
      V_CAN_TEXTO   := 0;
      V_VAL_TEXTO   := null;
      --Cuota Tarjeta
      V_LUGAR := '016.061-PP_DES_INF_ECO_FINANCIERA';
      select TO_NUMBER(DBMS_LOB.INSTR(V_INF_ECO_FIN_AUX, '~cuo_tarjeta<i:') +
                       LENGTH('~cuo_tarjeta<i:'))
        into V_INI_POS
        from DUAL;
      V_LUGAR := '016.062-PP_DES_INF_ECO_FINANCIERA';
      select DBMS_LOB.INSTR(V_INF_ECO_FIN_AUX, ':f>', (V_INI_POS), 1)
        into V_FIN_POS
        from DUAL;
      V_LUGAR     := '016.063-PP_DES_INF_ECO_FINANCIERA';
      V_CAN_TEXTO := NVL(V_FIN_POS, 0) - NVL(V_INI_POS, 0);
      V_LUGAR     := '016.064-PP_DES_INF_ECO_FINANCIERA';
      select replace(DBMS_LOB.SUBSTR(V_INF_ECO_FIN_AUX, V_CAN_TEXTO, V_INI_POS),
                     CHR(44),
                     CHR(46)) --DYDMR-3071 - Sergio Servín 14-06-2016 11:21 AM 
        into V_VAL_TEXTO
        from DUAL;
      V_LUGAR       := '016.065-PP_DES_INF_ECO_FINANCIERA';
      P_CUO_TARJETA := FUG_OBT_TEX_NUMERO(V_VAL_TEXTO);
      V_LUGAR       := '016.066-PP_DES_INF_ECO_FINANCIERA';
      V_INI_POS     := 0;
      V_FIN_POS     := 0;
      V_CAN_TEXTO   := 0;
      V_VAL_TEXTO   := null;
      --Cuota Hipoteca
      V_LUGAR := '016.067-PP_DES_INF_ECO_FINANCIERA';
      select TO_NUMBER(DBMS_LOB.INSTR(V_INF_ECO_FIN_AUX, '~cuo_hipoteca<i:') +
                       LENGTH('~cuo_hipoteca<i:'))
        into V_INI_POS
        from DUAL;
      V_LUGAR := '016.068-PP_DES_INF_ECO_FINANCIERA';
      select DBMS_LOB.INSTR(V_INF_ECO_FIN_AUX, ':f>', (V_INI_POS), 1)
        into V_FIN_POS
        from DUAL;
      V_LUGAR     := '016.069-PP_DES_INF_ECO_FINANCIERA';
      V_CAN_TEXTO := NVL(V_FIN_POS, 0) - NVL(V_INI_POS, 0);
      V_LUGAR     := '016.070-PP_DES_INF_ECO_FINANCIERA';
      select replace(DBMS_LOB.SUBSTR(V_INF_ECO_FIN_AUX, V_CAN_TEXTO, V_INI_POS),
                     CHR(44),
                     CHR(46)) --DYDMR-3071 - Sergio Servín 14-06-2016 11:21 AM 
        into V_VAL_TEXTO
        from DUAL;
      V_LUGAR        := '016.071-PP_DES_INF_ECO_FINANCIERA';
      P_CUO_HIPOTECA := FUG_OBT_TEX_NUMERO(V_VAL_TEXTO);
      V_LUGAR        := '016.072-PP_DES_INF_ECO_FINANCIERA';
      V_INI_POS      := 0;
      V_FIN_POS      := 0;
      V_CAN_TEXTO    := 0;
      V_VAL_TEXTO    := null;
      --Nueva Cuota
      V_LUGAR := '016.073-PP_DES_INF_ECO_FINANCIERA';
      select TO_NUMBER(DBMS_LOB.INSTR(V_INF_ECO_FIN_AUX, '~nue_cuota<i:') +
                       LENGTH('~nue_cuota<i:'))
        into V_INI_POS
        from DUAL;
      V_LUGAR := '016.074-PP_DES_INF_ECO_FINANCIERA';
      select DBMS_LOB.INSTR(V_INF_ECO_FIN_AUX, ':f>', (V_INI_POS), 1)
        into V_FIN_POS
        from DUAL;
      V_LUGAR     := '016.075-PP_DES_INF_ECO_FINANCIERA';
      V_CAN_TEXTO := NVL(V_FIN_POS, 0) - NVL(V_INI_POS, 0);
      V_LUGAR     := '016.076-PP_DES_INF_ECO_FINANCIERA';
      select replace(DBMS_LOB.SUBSTR(V_INF_ECO_FIN_AUX, V_CAN_TEXTO, V_INI_POS),
                     CHR(44),
                     CHR(46)) --DYDMR-3071 - Sergio Servín 14-06-2016 11:21 AM 
        into V_VAL_TEXTO
        from DUAL;
      V_LUGAR     := '016.077-PP_DES_INF_ECO_FINANCIERA';
      P_NUE_CUOTA := FUG_OBT_TEX_NUMERO(V_VAL_TEXTO);
      V_LUGAR     := '016.078-PP_DES_INF_ECO_FINANCIERA';
      V_INI_POS   := 0;
      V_FIN_POS   := 0;
      V_CAN_TEXTO := 0;
      V_VAL_TEXTO := null;
      --Alquileres Pagados
      V_LUGAR := '016.079-PP_DES_INF_ECO_FINANCIERA';
      select TO_NUMBER(DBMS_LOB.INSTR(V_INF_ECO_FIN_AUX, '~alq_pagado<i:') +
                       LENGTH('~alq_pagado<i:'))
        into V_INI_POS
        from DUAL;
      V_LUGAR := '016.080-PP_DES_INF_ECO_FINANCIERA';
      select DBMS_LOB.INSTR(V_INF_ECO_FIN_AUX, ':f>', (V_INI_POS), 1)
        into V_FIN_POS
        from DUAL;
      V_LUGAR     := '016.081-PP_DES_INF_ECO_FINANCIERA';
      V_CAN_TEXTO := NVL(V_FIN_POS, 0) - NVL(V_INI_POS, 0);
      V_LUGAR     := '016.082-PP_DES_INF_ECO_FINANCIERA';
      select replace(DBMS_LOB.SUBSTR(V_INF_ECO_FIN_AUX, V_CAN_TEXTO, V_INI_POS),
                     CHR(44),
                     CHR(46)) --DYDMR-3071 - Sergio Servín 14-06-2016 11:21 AM 
        into V_VAL_TEXTO
        from DUAL;
      V_LUGAR      := '016.083-PP_DES_INF_ECO_FINANCIERA';
      P_ALQ_PAGADO := FUG_OBT_TEX_NUMERO(V_VAL_TEXTO);
      V_LUGAR      := '016.084-PP_DES_INF_ECO_FINANCIERA';
      V_INI_POS    := 0;
      V_FIN_POS    := 0;
      V_CAN_TEXTO  := 0;
      V_VAL_TEXTO  := null;
      --Otras Cuotas
      V_LUGAR := '016.085-PP_DES_INF_ECO_FINANCIERA';
      select TO_NUMBER(DBMS_LOB.INSTR(V_INF_ECO_FIN_AUX, '~otr_cuota<i:') +
                       LENGTH('~otr_cuota<i:'))
        into V_INI_POS
        from DUAL;
      V_LUGAR := '016.086-PP_DES_INF_ECO_FINANCIERA';
      select DBMS_LOB.INSTR(V_INF_ECO_FIN_AUX, ':f>', (V_INI_POS), 1)
        into V_FIN_POS
        from DUAL;
      V_LUGAR     := '016.087-PP_DES_INF_ECO_FINANCIERA';
      V_CAN_TEXTO := NVL(V_FIN_POS, 0) - NVL(V_INI_POS, 0);
      V_LUGAR     := '016.088-PP_DES_INF_ECO_FINANCIERA';
      select replace(DBMS_LOB.SUBSTR(V_INF_ECO_FIN_AUX, V_CAN_TEXTO, V_INI_POS),
                     CHR(44),
                     CHR(46)) --DYDMR-3071 - Sergio Servín 14-06-2016 11:21 AM 
        into V_VAL_TEXTO
        from DUAL;
      V_LUGAR     := '016.089-PP_DES_INF_ECO_FINANCIERA';
      P_OTR_CUOTA := FUG_OBT_TEX_NUMERO(V_VAL_TEXTO);
      V_LUGAR     := '016.090-PP_DES_INF_ECO_FINANCIERA';
      V_INI_POS   := 0;
      V_FIN_POS   := 0;
      V_CAN_TEXTO := 0;
      V_VAL_TEXTO := null;
      --Total A
      V_LUGAR := '016.091-PP_DES_INF_ECO_FINANCIERA';
      select TO_NUMBER(DBMS_LOB.INSTR(V_INF_ECO_FIN_AUX, '~total_a<i:') +
                       LENGTH('~total_a<i:'))
        into V_INI_POS
        from DUAL;
      V_LUGAR := '016.092-PP_DES_INF_ECO_FINANCIERA';
      select DBMS_LOB.INSTR(V_INF_ECO_FIN_AUX, ':f>', (V_INI_POS), 1)
        into V_FIN_POS
        from DUAL;
      V_LUGAR     := '016.093-PP_DES_INF_ECO_FINANCIERA';
      V_CAN_TEXTO := NVL(V_FIN_POS, 0) - NVL(V_INI_POS, 0);
      V_LUGAR     := '016.094-PP_DES_INF_ECO_FINANCIERA';
      select replace(DBMS_LOB.SUBSTR(V_INF_ECO_FIN_AUX, V_CAN_TEXTO, V_INI_POS),
                     CHR(44),
                     CHR(46)) --DYDMR-3071 - Sergio Servín 14-06-2016 11:21 AM
        into V_VAL_TEXTO
        from DUAL;
      V_LUGAR     := '016.095-PP_DES_INF_ECO_FINANCIERA';
      P_TOTAL_A   := FUG_OBT_TEX_NUMERO(V_VAL_TEXTO);
      V_LUGAR     := '016.096-PP_DES_INF_ECO_FINANCIERA';
      V_INI_POS   := 0;
      V_FIN_POS   := 0;
      V_CAN_TEXTO := 0;
      V_VAL_TEXTO := null;
      --Total B
      V_LUGAR := '016.097-PP_DES_INF_ECO_FINANCIERA';
      select TO_NUMBER(DBMS_LOB.INSTR(V_INF_ECO_FIN_AUX, '~total_b<i:') +
                       LENGTH('~total_b<i:'))
        into V_INI_POS
        from DUAL;
      V_LUGAR := '016.098-PP_DES_INF_ECO_FINANCIERA';
      select DBMS_LOB.INSTR(V_INF_ECO_FIN_AUX, ':f>', (V_INI_POS), 1)
        into V_FIN_POS
        from DUAL;
      V_LUGAR     := '016.099-PP_DES_INF_ECO_FINANCIERA';
      V_CAN_TEXTO := NVL(V_FIN_POS, 0) - NVL(V_INI_POS, 0);
      V_LUGAR     := '016.100-PP_DES_INF_ECO_FINANCIERA';
      select replace(DBMS_LOB.SUBSTR(V_INF_ECO_FIN_AUX, V_CAN_TEXTO, V_INI_POS),
                     CHR(44),
                     CHR(46)) --DYDMR-3071 - Sergio Servín 14-06-2016 11:21 AM
        into V_VAL_TEXTO
        from DUAL;
      V_LUGAR     := '016.101-PP_DES_INF_ECO_FINANCIERA';
      P_TOTAL_B   := FUG_OBT_TEX_NUMERO(V_VAL_TEXTO);
      V_LUGAR     := '016.102-PP_DES_INF_ECO_FINANCIERA';
      V_INI_POS   := 0;
      V_FIN_POS   := 0;
      V_CAN_TEXTO := 0;
      V_VAL_TEXTO := null;
      --Ingresos menos Egresos
      V_LUGAR := '016.103-PP_DES_INF_ECO_FINANCIERA';
      select TO_NUMBER(DBMS_LOB.INSTR(V_INF_ECO_FIN_AUX, '~ing_men_egresos<i:') +
                       LENGTH('~ing_men_egresos<i:'))
        into V_INI_POS
        from DUAL;
      V_LUGAR := '016.104-PP_DES_INF_ECO_FINANCIERA';
      select DBMS_LOB.INSTR(V_INF_ECO_FIN_AUX, ':f>', (V_INI_POS), 1)
        into V_FIN_POS
        from DUAL;
      V_LUGAR     := '016.105-PP_DES_INF_ECO_FINANCIERA';
      V_CAN_TEXTO := NVL(V_FIN_POS, 0) - NVL(V_INI_POS, 0);
      V_LUGAR     := '016.106-PP_DES_INF_ECO_FINANCIERA';
      select replace(DBMS_LOB.SUBSTR(V_INF_ECO_FIN_AUX, V_CAN_TEXTO, V_INI_POS),
                     CHR(44),
                     CHR(46)) --DYDMR-3071 - Sergio Servín 14-06-2016 11:21 AM 
        into V_VAL_TEXTO
        from DUAL;
      V_LUGAR           := '016.107-PP_DES_INF_ECO_FINANCIERA';
      P_ING_MEN_EGRESOS := FUG_OBT_TEX_NUMERO(V_VAL_TEXTO);
      V_LUGAR           := '016.108-PP_DES_INF_ECO_FINANCIERA';
      V_INI_POS         := 0;
      V_FIN_POS         := 0;
      V_CAN_TEXTO       := 0;
      V_VAL_TEXTO       := null;
      --Total Cuotas vs Ingresos
      V_LUGAR := '016.109-PP_DES_INF_ECO_FINANCIERA';
      select TO_NUMBER(DBMS_LOB.INSTR(V_INF_ECO_FIN_AUX, '~tot_cuo_ingresos<i:') +
                       LENGTH('~tot_cuo_ingresos<i:'))
        into V_INI_POS
        from DUAL;
      V_LUGAR := '016.110-PP_DES_INF_ECO_FINANCIERA';
      select DBMS_LOB.INSTR(V_INF_ECO_FIN_AUX, ':f>', (V_INI_POS), 1)
        into V_FIN_POS
        from DUAL;
      V_LUGAR     := '016.111-PP_DES_INF_ECO_FINANCIERA';
      V_CAN_TEXTO := NVL(V_FIN_POS, 0) - NVL(V_INI_POS, 0);
      V_LUGAR     := '016.112-PP_DES_INF_ECO_FINANCIERA';
      select replace(DBMS_LOB.SUBSTR(V_INF_ECO_FIN_AUX, V_CAN_TEXTO, V_INI_POS),
                     CHR(44),
                     CHR(46)) --DYDMR-3071 - Sergio Servín 14-06-2016 11:21 AM 
        into V_VAL_TEXTO
        from DUAL;
      V_LUGAR            := '016.113-PP_DES_INF_ECO_FINANCIERA';
      P_TOT_CUO_INGRESOS := FUG_OBT_TEX_NUMERO(V_VAL_TEXTO);
      V_LUGAR            := '016.114-PP_DES_INF_ECO_FINANCIERA';
      V_INI_POS          := 0;
      V_FIN_POS          := 0;
      V_CAN_TEXTO        := 0;
      V_VAL_TEXTO        := null;
      --Cuota Solicitud vs Ingresos
      V_LUGAR := '016.115-PP_DES_INF_ECO_FINANCIERA';
      select TO_NUMBER(DBMS_LOB.INSTR(V_INF_ECO_FIN_AUX, '~cuo_sol_ingresos<i:') +
                       LENGTH('~cuo_sol_ingresos<i:'))
        into V_INI_POS
        from DUAL;
      V_LUGAR := '016.116-PP_DES_INF_ECO_FINANCIERA';
      select DBMS_LOB.INSTR(V_INF_ECO_FIN_AUX, ':f>', (V_INI_POS), 1)
        into V_FIN_POS
        from DUAL;
      V_LUGAR     := '016.117-PP_DES_INF_ECO_FINANCIERA';
      V_CAN_TEXTO := NVL(V_FIN_POS, 0) - NVL(V_INI_POS, 0);
      V_LUGAR     := '016.118-PP_DES_INF_ECO_FINANCIERA';
      select replace(DBMS_LOB.SUBSTR(V_INF_ECO_FIN_AUX, V_CAN_TEXTO, V_INI_POS),
                     CHR(44),
                     CHR(46)) --DYDMR-3071 - Sergio Servín 14-06-2016 11:21 AM 
        into V_VAL_TEXTO
        from DUAL;
      V_LUGAR            := '016.119-PP_DES_INF_ECO_FINANCIERA';
      P_CUO_SOL_INGRESOS := FUG_OBT_TEX_NUMERO(V_VAL_TEXTO);
      V_LUGAR            := '016.120-PP_DES_INF_ECO_FINANCIERA';
      V_INI_POS          := 0;
      V_FIN_POS          := 0;
      V_CAN_TEXTO        := 0;
      V_VAL_TEXTO        := null;
   end if;
end;
/

