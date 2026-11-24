CREATE OR REPLACE TRIGGER IT.TA_CC_SOBREGIROS_RES
AFTER INSERT OR UPDATE
ON CC_SOBREGIROS_RES
FOR EACH ROW

BEGIN
  --Actualiza la tabla ge_cuentas
  IF nvl(:old.can_dias,0) <> nvl(:new.can_dias,0) OR
     nvl(:old.pro_atraso,0) <> nvl(:new.pro_atraso,0) OR
     nvl(:old.max_atraso,0) <> nvl(:new.max_atraso,0) OR
     nvl(:old.mto_mora,0) <> nvl(:new.mto_mora,0) THEN
     UPDATE ge_cuentas
        set dia_atraso = :new.can_dias,
            pro_atraso = :new.pro_atraso,
            max_atraso = :new.max_atraso,
            mto_mora   = :new.mto_mora
      where nro_cuenta = :new.nro_cuenta;
  END IF;

  IF nvl(:new.mto_mora,0) = 0 then
    UPDATE ge_cuentas
        set dia_atraso = 0,
            mto_mora   = 0
      where nro_cuenta = :old.nro_cuenta;
  END IF;

  -- 13/06/2013 AL-DyD. Actualiza dia_atraso, max_atraso, pro_atraso, mto_mora y mto_sob_suspenso de cc_cta_corriente.
  IF nvl(:old.can_dias,0) <> nvl(:new.can_dias,0) OR
     nvl(:old.pro_atraso,0) <> nvl(:new.pro_atraso,0) OR
     nvl(:old.max_atraso,0) <> nvl(:new.max_atraso,0) OR
     nvl(:old.mto_mora,0) <> nvl(:new.mto_mora,0) OR
     nvl(:old.mto_sob_suspenso,0) <> nvl(:new.mto_sob_suspenso,0) THEN
     UPDATE cc_cta_corrientes
       set dia_atraso = :new.can_dias,
          pro_atraso = :new.pro_atraso,
          max_atraso = :new.max_atraso,
          mto_mora   = :new.mto_mora,
          mto_sob_suspenso = :new.mto_sob_suspenso
     where nro_cuenta = :new.nro_cuenta;
  END IF;
  --
END;
/

