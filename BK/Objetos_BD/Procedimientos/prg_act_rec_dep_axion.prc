CREATE OR REPLACE PROCEDURE IT.prg_act_rec_dep_axion IS
  v_cod_ente  number := 7834; -- código de ente Axion
  v_cod_tip_doc ba_personas.cod_tip_documento%type;
  CURSOR c_dat IS
  SELECT *
    FROM ge_rec_dep_axion;
BEGIN
  FOR k IN c_dat LOOP
    IF k.tip_doc_depositante is not null THEN
      if k.tip_doc_depositante = '50' then
        v_cod_tip_doc := 6;
      else
        v_cod_tip_doc := 1;
      end if;
    END IF;
    --
    BEGIN
      INSERT INTO ge_rec_depositantes
      (cod_ente, cod_depositante, cod_tip_documento, nro_documento, nom_depositante, activo)
      VALUES
      (v_cod_ente, k.cod_dep_ini, v_cod_tip_doc, k.nro_doc_depositante, k.nombre, 'S');
    EXCEPTION
      WHEN OTHERS THEN
        IF INSTR(SQLERRM,'PK_GE_REC_') > 0 THEN
          raise_application_error(-20000,'Código Depositante '||k.cod_dep_ini||' ya Registrado.');
        ELSE
          raise_application_error(-20000,'Error en prg_act_rec_dep_axion '||sqlerrm);
        END IF;
    END;

  END LOOP;
END;
/

