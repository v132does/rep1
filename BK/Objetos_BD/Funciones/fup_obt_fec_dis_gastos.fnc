CREATE OR REPLACE FUNCTION IT.fup_obt_fec_dis_gastos (P_NRO_CUENTA      IN VARCHAR2,
                                                   P_COD_TRANSACCION IN NUMBER,
                                                   P_FEC_INGRESO     IN DATE,
                                                   P_NRO_SOLICITUD   IN NUMBER) RETURN DATE IS
   v_hora         ge_movimientos.hora%type;
   v_fec_ingreso  DATE;
   v_can_bus_hora NUMBER(8);
   v_existe       VARCHAR2(1);
   v_hor_agotada  VARCHAR2(1);
BEGIN
   v_hora         := to_char(SYSDATE,'hh24:mi:ss');
   v_fec_ingreso  := to_date(to_char(p_fec_ingreso,'DD/MM/YYYY')||' '||v_hora,'DD/MM/YYYY HH24:MI;SS');
   v_can_bus_hora := 0;
   v_hor_agotada  := 'N';
   v_existe       := 'N';
   LOOP
      v_can_bus_hora := nvl(v_can_bus_hora,0) + 1;
      BEGIN
         SELECT 'S'
           INTO v_existe
           FROM pr_cta_gastos x
          WHERE x.nro_cuenta = p_nro_cuenta
            AND x.cod_transaccion = p_cod_transaccion
            AND x.fec_ingreso = v_fec_ingreso
            AND x.nro_solicitud = p_nro_solicitud;
      EXCEPTION
         WHEN no_data_found THEN
            v_existe := 'N';
      END;
      EXIT WHEN ((v_existe = 'N') or (v_hor_agotada = 'S'));
      v_hora := pag_gen.fu_obt_sig_segundo(v_hora);
      v_fec_ingreso := to_date(to_char(p_fec_ingreso,'DD/MM/YYYY')||' '||v_hora,'DD/MM/YYYY HH24:MI:SS');
      IF v_can_bus_hora >= 85000 THEN
         v_hor_agotada := 'S';
      END IF;
   END LOOP;
   IF v_hor_agotada = 'S' THEN
      raise_application_error(-20000,'Error. No existe hora disponible para PR_CTA_GASTOS (FEC_INGRESO)'); 
   END IF;
   RETURN v_fec_ingreso;
EXCEPTION
   WHEN others THEN
      raise_application_error(-20000,'Error en fup_obt_fec_dis_gastos :'||sqlerrm); 
END;
/

