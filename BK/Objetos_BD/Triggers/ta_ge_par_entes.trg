CREATE OR REPLACE TRIGGER IT.ta_ge_par_entes
  FOR UPDATE OF val_parametro ON ge_par_entes
COMPOUND TRIGGER
  TYPE typ_val_parametro    IS TABLE OF ge_par_entes.val_parametro%type;
  TYPE typ_ente             IS TABLE OF ge_entes.cod_ente%TYPE;
  TYPE typ_entevalparametro IS TABLE OF ge_par_entes.val_parametro%TYPE INDEX BY VARCHAR2(80);
  vt_val_parametro          typ_val_parametro;
  vt_ente                   typ_ente;
  vt_entevalparametro       typ_entevalparametro;
  v_es_hub_global           varchar2(1) := 'N';
  v_cod_persona             varchar2(10);
  v_tip_hg                  varchar2(10) := 'PAGPRV';

  BEFORE STATEMENT IS
  BEGIN
    SELECT a.val_parametro, a.cod_ente BULK COLLECT
      INTO vt_val_parametro, vt_ente
      FROM ge_par_entes a
     WHERE a.parametro = 'HAB_PRV_HUB_GLOBAL';

    FOR j IN 1..vt_ente.COUNT() LOOP
      vt_entevalparametro(vt_ente(j)) := vt_val_parametro(j);
    END LOOP;
    --
    DELETE ge_cta_hub_global_tmp;
    INSERT INTO ge_cta_hub_global_tmp(cod_ente, parametro, val_parametro)
    SELECT a.cod_ente, b.parametro, b.val_parametro
      FROM ge_entes a, ge_par_entes b
     WHERE a.cod_ente = b.cod_ente
       AND a.tipo = 'PR'
       AND b.parametro like 'CTA_DEB_PPROV%'
       AND b.val_parametro is not null;
  END BEFORE STATEMENT;

  AFTER EACH ROW IS
  BEGIN
    -- Alta / baja de Clientes.
    if :new.parametro = 'HAB_PRV_HUB_GLOBAL' then
      if :new.val_parametro not in ('S','N') then
        raise_application_error(-20000, 'Valor debe ser S o N.');
      else
        begin
          select a.cod_persona
            into v_cod_persona
            from ge_entes a
           where a.cod_ente = :new.cod_ente;
        end;
        if nvl(:old.val_parametro,'N') = 'N' and :new.val_parametro = 'S' then
          paw_prv.pr_ins_notificaciones(:new.cod_ente, 10, v_cod_persona, v_tip_hg, 'I');
          paw_prv.pr_ins_notificaciones(:new.cod_ente, 20, v_cod_persona, v_tip_hg, 'I');
          for k in (select * from ge_cta_hub_global_tmp a
                     where a.cod_ente = :new.cod_ente) loop
            paw_prv.pr_ins_notificaciones(k.cod_ente, 30, v_cod_persona, v_tip_hg, 'I', k.parametro, k.val_parametro);
          end loop;
        elsif :old.val_parametro = 'S' and (:new.val_parametro = 'N' or :new.val_parametro is null) then
          for k in (select * from ge_cta_hub_global_tmp a
                     where a.cod_ente = :new.cod_ente) loop
            paw_prv.pr_ins_notificaciones(k.cod_ente, 31, v_cod_persona, v_tip_hg, 'I', k.parametro, k.val_parametro);
          end loop;
          paw_prv.pr_ins_notificaciones(:new.cod_ente, 11, v_cod_persona, v_tip_hg, 'I');
        end if;
      end if;
    end if;
    -- Alta / baja de Cuentas
    IF :new.parametro like 'CTA_DEB_PPROV%' THEN
      v_es_hub_global := vt_entevalparametro(:NEW.cod_ente);
      IF v_es_hub_global = 'S' and
        (nvl(:old.val_parametro,'x') != nvl(:new.val_parametro,'x')) THEN
        BEGIN
          SELECT a.cod_persona
            INTO v_cod_persona
            FROM ge_entes a
           WHERE a.cod_ente = :new.cod_ente;
        END;

        IF :old.val_parametro IS NOT NULL THEN
          paw_prv.pr_ins_notificaciones(:new.cod_ente, 31, v_cod_persona, v_tip_hg, 'I', :new.parametro, :old.val_parametro);
        END IF;

        IF :new.val_parametro IS NOT NULL THEN
          paw_prv.pr_ins_notificaciones(:new.cod_ente, 30, v_cod_persona, v_tip_hg, 'I', :new.parametro, :new.val_parametro);
        END IF;

      END IF;
    END IF;
  END AFTER EACH ROW;
END ta_ge_par_entes;
/

