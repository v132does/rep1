CREATE OR REPLACE PROCEDURE IT.pre_gen_rep_generico IS
   v_sentencia  ba_def_reportes.sentencia%TYPE;
   v_fec_actual ge_calendarios.fec_actual%TYPE;
   v_resultado  ba_rep_valores.valor%TYPE;

   CURSOR def IS
      SELECT a.cod_programa, a.nro_orden, a.descripcion, a.negrita, a.separador, a.sentencia
        FROM ba_def_reportes a
       ORDER BY a.cod_programa, a.sec_ejecucion;
BEGIN
   v_fec_actual := pag_cal.fu_obt_fec_actual(2);
   DELETE FROM ba_rep_valores WHERE fecha = v_fec_actual;
   FOR i IN def LOOP

      v_sentencia := i.sentencia;
      v_sentencia := REPLACE(v_sentencia, '&' || 'v_fec_actual', '''' || v_fec_actual || '''');
      v_sentencia := REPLACE(v_sentencia, '&' || 'v_cod_programa', '''' || i.cod_programa || '''');

      EXECUTE IMMEDIATE v_sentencia
         INTO v_resultado;

      INSERT INTO ba_rep_valores
         (cod_programa, nro_orden, fecha, valor)
      VALUES
         (i.cod_programa, i.nro_orden, v_fec_actual, nvl(v_resultado, 0));

   END LOOP;
   COMMIT;
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000, 'Error al actualizar ba_rep_valores.' || SQLERRM);
END;
/

