CREATE OR REPLACE TRIGGER IT.TA_GE_PAG_SUE_EMP_TMP
   AFTER INSERT OR UPDATE ON GE_PAG_SUE_EMP_TMP
   FOR EACH ROW
DECLARE
   v_cli_existe VARCHAR2(1);
BEGIN
   IF inserting OR updating THEN
      BEGIN
         SELECT 'S'
           INTO v_cli_existe
           FROM ge_pag_sue_emp_tmp_err
          WHERE nro_cedula = nvl(:new.nro_cedula, :old.nro_cedula)
            AND error = :new.error;
      
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            v_cli_existe := 'N';
         WHEN TOO_MANY_ROWS THEN
            v_cli_existe := 'S';
      END;
   
      IF NVL(v_cli_existe, 'N') = 'N' AND nvl(:old.error, 0) <> nvl(:new.error, 0) THEN
         INSERT INTO ge_pag_sue_emp_tmp_err
         VALUES
            (:new.cod_empresa, :new.nro_cedula, :new.pri_nombre, :new.seg_nombre, :new.pri_apellido, 
            :new.seg_apellido, :new.fec_nacimiento, :new.sexo, :new.est_civil, :new.direccion, 
            :new.ciudad, :new.telefono, :new.sueldo, :new.mto_ant_sueldo, :new.mto_ant_aguinaldo, 
            :new.generar, :new.nro_cta_ahorro, :new.fec_ingreso, :new.tip_documento, :new.tip_tarjeta, 
            :new.fec_vto_documento, :new.nro_direccion, :new.error, :new.ape_casada, :new.nro_solicitud, 
            :new.gen_cuenta, NULL, NULL, NULL, NULL);
      
      ELSIF NVL(v_cli_existe, 'S') = 'S' AND nvl(:old.error, 0) <> nvl(:new.error, 0) THEN
         UPDATE ge_pag_sue_emp_tmp_err a
            SET a.cod_empresa       = :new.cod_empresa,
                a.nro_cedula        = :new.Nro_Cedula,
                a.pri_nombre        = :new.pri_nombre,
                a.seg_nombre        = :new.seg_nombre,
                a.pri_apellido      = :new.pri_apellido,
                a.seg_apellido      = :new.seg_apellido,
                a.fec_nacimiento    = :new.fec_nacimiento,
                a.sexo              = :new.sexo,
                a.est_civil         = :new.est_civil,
                a.direccion         = :new.direccion,
                a.ciudad            = :new.ciudad,
                a.telefono          = :new.telefono,
                a.sueldo            = :new.sueldo,
                a.mto_ant_sueldo    = :new.mto_ant_sueldo,
                a.mto_ant_aguinaldo = :new.mto_ant_aguinaldo,
                a.generar           = :new.generar,
                a.nro_cta_ahorro    = :new.nro_cta_ahorro,
                a.fec_ingreso       = :new.fec_ingreso,
                a.tip_documento     = :new.tip_documento,
                a.tip_tarjeta       = :new.tip_tarjeta,
                a.fec_vto_documento = :new.fec_vto_documento,
                a.nro_direccion     = :new.nro_direccion,
                a.error             = :new.error,
                a.ape_casada        = :new.ape_casada,
                a.nro_solicitud     = :new.nro_solicitud,
                a.gen_cuenta        = :new.gen_cuenta
          WHERE a.nro_cedula = :new.nro_cedula
            AND a.error = :new.error
            AND a.fec_insercion = (SELECT MAX(fec_insercion)
                                     FROM ge_pag_sue_emp_tmp_err b
                                    WHERE b.nro_cedula = a.nro_cedula
                                      AND b.error = a.error);
      END IF;
   END IF;
END;
/

