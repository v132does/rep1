CREATE OR REPLACE FUNCTION IT.fug_obt_fec_sig_habil
(
   p_fecha       IN DATE,
   p_cod_oficina IN ba_oficinas.cod_oficina%TYPE /*DEFAULT fun_obt_ofi_matriz*/,
   p_dias        IN NUMBER DEFAULT 0
) RETURN DATE IS
   v_fec_proxima       DATE;
   v_ult_dia_mes_habil DATE;
   v_can_dias          NUMBER(8);
   v_mes               VARCHAR2(2);
   v_cod_entidad       ge_par_generales.cod_entidad%TYPE := pag_gen.fu_obt_cod_entidad;
BEGIN
   v_can_dias    := 0;
   v_fec_proxima := p_fecha;
   /* le agrego por si la fecha inicio ya es feriado o no hábil */
   IF fue_ctr_fec_feriado(v_fec_proxima, p_cod_oficina) OR
      TRIM(to_char(v_fec_proxima, 'DAY')) IN ('SATURDAY', 'SABADO', 'SÁBADO', 'SUNDAY', 'DOMINGO') THEN
      v_fec_proxima := pag_cal.fu_obt_fec_sig_hab(p_fecha, p_cod_oficina, 1);
      v_can_dias    := 1;
   END IF;
   LOOP
      EXIT WHEN v_can_dias >= p_dias;
      v_fec_proxima := v_fec_proxima + 1;
      --- Verificar si es feriado o sábado o domingo
      IF NOT fue_ctr_fec_feriado(v_fec_proxima, p_cod_oficina) AND
         TRIM(to_char(v_fec_proxima, 'DAY')) NOT IN
         ('SATURDAY', 'SABADO', 'SÁBADO', 'SUNDAY', 'DOMINGO') THEN
         v_can_dias := v_can_dias + 1;
      END IF;
   END LOOP;
   -- retorno la próxima fecha
   RETURN v_fec_proxima;
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000, 'FUG_OBT_FEC_SIG_HABIL: ' || to_char(p_fecha, 'DD/MM/YYYY') || ' Inválida. '||sqlerrm);
END;
/

