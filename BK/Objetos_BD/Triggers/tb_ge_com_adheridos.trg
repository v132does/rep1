CREATE OR REPLACE TRIGGER IT.tb_ge_com_adheridos
BEFORE INSERT OR UPDATE ON IT.ge_com_adheridos
FOR EACH ROW
DECLARE
    v_count NUMBER;
BEGIN
    -- Comprobar si existe un duplicado en la inserción
    IF INSERTING THEN
      SELECT COUNT(*)
        INTO v_count
        FROM IT.ge_com_adheridos
       WHERE cod_cli_comercio = :NEW.cod_cli_comercio
         AND cod_comercio = :NEW.cod_comercio
         AND cod_promocion = :NEW.cod_promocion
         AND fec_inicio = :NEW.fec_inicio
         AND fec_fin = :NEW.fec_fin;

        IF v_count > 0 THEN
             raise_application_error(-20000,'Error en IT.ge_com_adheridos '||' Código de Cliente del comercio '||:new.cod_cli_comercio||'-'||' Codigo del Comercio '||:new.cod_comercio||' Codigo de Promocion '||:new.cod_promocion||'-'||' Fecha inicio '||:new.fec_inicio||'-'||' Fecha fin '||:new.fec_fin);
        END IF;

    -- Comprobar si existe un duplicado en la actualización
    ELSIF UPDATING THEN
      SELECT COUNT(*)
        INTO v_count
        FROM IT.ge_com_adheridos
       WHERE cod_cli_comercio = :NEW.cod_cli_comercio
         AND cod_comercio = :NEW.cod_comercio
         AND cod_promocion = :NEW.cod_promocion
         AND fec_inicio = :NEW.fec_inicio
         AND fec_fin = :NEW.fec_fin;

        IF v_count > 0 THEN
             raise_application_error(-20000,'Error en IT.ge_com_adheridos '||' Código de Cliente del comercio '||:new.cod_cli_comercio||'-'||' Codigo del Comercio '||:new.cod_comercio||' Codigo de Promocion '||:new.cod_promocion||'-'||' Fecha inicio '||:new.fec_inicio||'-'||' Fecha fin '||:new.fec_fin);
        END IF;
    END IF;
END;
/
