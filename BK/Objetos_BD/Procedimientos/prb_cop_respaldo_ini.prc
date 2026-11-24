CREATE OR REPLACE PROCEDURE IT.prb_cop_respaldo_ini IS
   v_msj VARCHAR2(250);
BEGIN
   v_msj := NULL;
   sql_util.ejecute_dml('TRUNCATE TABLE cb_sal_oficinas_ini DROP STORAGE', v_msj);
   IF v_msj IS NOT NULL THEN
      raise_application_error(-20001, v_msj);
   END IF;
   v_msj := NULL;
   sql_util.ejecute_dml('TRUNCATE TABLE cb_sal_consolidados_ini DROP STORAGE', v_msj);
   IF v_msj IS NOT NULL THEN
      raise_application_error(-20002, v_msj);
   END IF;
   v_msj := NULL;
   sql_util.ejecute_dml('TRUNCATE TABLE cb_sal_oficinas_dia_ini DROP STORAGE', v_msj);
   IF v_msj IS NOT NULL THEN
      raise_application_error(-20003, v_msj);
   END IF;
   v_msj := NULL;
   sql_util.ejecute_dml('TRUNCATE TABLE cb_sal_consolidados_dia_ini DROP STORAGE', v_msj);
   IF v_msj IS NOT NULL THEN
      raise_application_error(-20004, v_msj);
   END IF;
   sql_util.ejecute_dml('TRUNCATE TABLE cb_asientos_his_ini DROP STORAGE', v_msj);
   IF v_msj IS NOT NULL THEN
      raise_application_error(-20005, v_msj);
   END IF;
   v_msj := NULL;
   sql_util.ejecute_dml('TRUNCATE TABLE cb_asientos_det_his_ini DROP STORAGE', v_msj);
   IF v_msj IS NOT NULL THEN
      raise_application_error(-20006, v_msj);
   END IF;
   v_msj := NULL;
   sql_util.ejecute_dml('TRUNCATE TABLE cb_asientos_ini DROP STORAGE', v_msj);
   IF v_msj IS NOT NULL THEN
      raise_application_error(-20007, v_msj);
   END IF;
   v_msj := NULL;
   sql_util.ejecute_dml('TRUNCATE TABLE cb_asientos_det_ini DROP STORAGE', v_msj);
   IF v_msj IS NOT NULL THEN
      raise_application_error(-20008, v_msj);
   END IF;
   v_msj := NULL;
   sql_util.ejecute_dml('TRUNCATE TABLE cb_sal_promedios_ini DROP STORAGE', v_msj);
   IF v_msj IS NOT NULL THEN
      raise_application_error(-20009, v_msj);
   END IF;
   INSERT INTO cb_sal_oficinas_ini
      SELECT * FROM cb_sal_oficinas;
   INSERT INTO cb_sal_consolidados_ini
      SELECT * FROM cb_sal_consolidados;
   INSERT INTO cb_sal_oficinas_dia_ini
      SELECT * FROM cb_sal_oficinas_dia;
   INSERT INTO cb_sal_consolidados_dia_ini
      SELECT * FROM cb_sal_consolidados_dia;
   INSERT INTO cb_asientos_his_ini
      SELECT * FROM cb_asientos_his;
   INSERT INTO cb_asientos_det_his_ini
      SELECT * FROM cb_asientos_det_his;
   INSERT INTO cb_asientos_ini
      SELECT * FROM cb_asientos;
   INSERT INTO cb_asientos_det_ini
      SELECT * FROM cb_asientos_det;
   INSERT INTO cb_sal_promedios_ini
      SELECT * FROM cb_sal_promedios;
END;
/

