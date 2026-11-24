CREATE OR REPLACE FUNCTION IT.FUL_CLI_OPE_CAMBIOS_PROBANDO
 (P_COD_PERSONA   BA_PERSONAS.COD_PERSONA%TYPE,
  P_MONTO GE_MOVIMIENTOS.MONTO%TYPE,
  P_COD_MONEDA BA_MONEDAS.COD_MONEDA%TYPE,
  P_FECHA GE_MOVIMIENTOS.FECHA%TYPE,
  P_IND_SUMA VARCHAR := 'N',
  P_COD_MAD_PADRE GE_MOVIMIENTOS.COD_MAD_PADRE%TYPE)
 RETURN NUMBER
 IS
 -- P_IND_SUMA is es igual a 'S' entoncces
 -- se halla la sumatoria de todas las operaciones de cambio, de la fecha, dolarizadas por el 
 -- P_COD_PERSONA que se recibe como parametro y se verifica si sumperan los 30000 usd
 -- para clasificarlos 
 -- si P_INS_SUMA es igual a 'N' se devuelve la clasificacion del cliente sin importar
 -- los montos de cada operacion
 v_monto  number(18,2);
 v_cla  number(2); -- clasificacion
 v_cod_sec_contable ge_clientes.cod_sec_contable%type;
 v_cod_tip_deudor ge_clientes.cod_tip_deudor%type;
 v_tot_cliente ge_movimientos.monto%type;
 v_mon_fuerte ge_movimientos.cod_moneda%type;
 /*
 1 Ramo Banco p/ operaciones > 30000
 2 Ramo Casa de Cambio p/ operaciones > 30000
 3 Ramo Financieras p/ operaciones > 30000
 4 Ramo Soc. Ahorro y Ptmos para la vivienda p/ operaciones > 30000
 5 Particulares p/ operaciones > 30000
 6 Sector Publico p/ operaciones > 30000
 7 Arbitraje  no utilizaremos pero figurara como una casilla mas
 8 Todas las operaciones cosolidadas < 30000 USD
 9 Otras operaciones especificas no utilizaremos pero figurara como una casilla mas
 */
BEGIN
   BEGIN
      v_mon_fuerte := pag_gen.fu_obt_mon_fuerte;
      v_cla := 8;  
      IF P_IND_SUMA = 'S' then
          select sum(decode(ge_movimientos.cod_moneda,
                    v_mon_fuerte,
                     ge_movimientos.monto,
                     pag_gen.FU_CON_MON_A_MONEDA(ge_movimientos.cod_moneda,
                                                 v_mon_fuerte,
                                                 ge_movimientos.monto))) sub_tot_monto
         into v_tot_cliente
         from (select fecha,hora, cod_usuario, nro_documento, nro_documento2 cod_persona
                 from ge_movimientos
                 where cod_transaccion = 760) cliente,
               ge_movimientos
         where cliente.fecha(+) = ge_movimientos.fecha and
               cliente.hora(+) = ge_movimientos.hora and
               cliente.cod_usuario(+) = ge_movimientos.cod_usuario and
               cliente.nro_documento(+) = ge_movimientos.nro_documento and
               ge_movimientos.reversado = 'N' and 
               ge_movimientos.COD_MOD_PADRE = 7 and
               ge_movimientos.nro_secuencia = 1 and
               ge_movimientos.cod_mad_padre in (71, 72) 
               and cliente.cod_persona  = P_COD_PERSONA
               and ge_movimientos.fecha = P_FECHA
               and ge_movimientos.cod_mad_padre = P_COD_MAD_PADRE
         group by cliente.fecha, cliente.cod_persona
         UNION
 select sum(decode(lc_movimientos_his.cod_moneda,
                    v_mon_fuerte,
                     lc_movimientos_his.monto,
                     pag_gen.FU_CON_MON_A_MONEDA(lc_movimientos_his.cod_moneda,
                                                 v_mon_fuerte,
                                                 lc_movimientos_his.monto))) sub_tot_monto
         --into v_tot_cliente
         from (select fecha,hora, cod_usuario, nro_documento, nro_documento2 cod_persona
                 from lc_movimientos_his
                 where cod_transaccion = 760) cliente,
               lc_movimientos_his
         where cliente.fecha(+) = lc_movimientos_his.fecha and
               cliente.hora(+) = lc_movimientos_his.hora and
               cliente.cod_usuario(+) = lc_movimientos_his.cod_usuario and
               cliente.nro_documento(+) = lc_movimientos_his.nro_documento and
               lc_movimientos_his.reversado = 'N' and 
               lc_movimientos_his.COD_MOD_PADRE = 7 and
               lc_movimientos_his.nro_secuencia = 1 and
               lc_movimientos_his.cod_mad_padre in (71, 72)    
               and cliente.cod_persona  = P_COD_PERSONA
               and lc_movimientos_his.fecha = P_FECHA
               and lc_movimientos_his.cod_mad_padre = P_COD_MAD_PADRE
         group by cliente.fecha, cliente.cod_persona;
      END IF;
   EXCEPTION
      WHEN no_data_found THEN
         V_TOT_CLIENTE := 0;
   END; 
   
      
    IF nvl(V_TOT_CLIENTE,0) < 30000 AND NVL(P_IND_SUMA,'N') = 'S'  THEN  -- clasificacion 8 
    v_cla := 8;
     
    ELSE
    
    begin
      select ge_clientes.cod_sec_contable, ge_clientes.cod_tip_deudor
      into v_cod_sec_contable, v_cod_tip_deudor
      from ge_clientes
      where cod_persona = P_COD_PERSONA;
   exception
      when no_data_found then
        v_cla := 5; -- Cuando es una persona va como sector particular
    end;     
      if v_cod_sec_contable = 'N' then            -- sector particular
          v_cla := 5;
      elsif v_cod_sec_contable = 'P' then         -- sector publico
          v_cla := 6;
      elsif v_cod_sec_contable in ('F','I') then  -- sector financiero
         if v_cod_tip_deudor IN (1,2,4,7) then    -- banco
            v_cla := 1;         
         elsif v_cod_tip_deudor IN (8) then       -- casa de cambio
             v_cla := 2;                     
         elsif v_cod_tip_deudor IN (3,6,9,10,11,15) then -- financeras             
             v_cla := 3;
         elsif v_cod_tip_deudor IN (14) then      -- Soc. Ahorros y Pmos. para la vivienda
             v_cla := 4;                         
         end if;
      end if;
 END IF;
 return v_cla;
END;
/

