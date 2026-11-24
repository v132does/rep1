CREATE OR REPLACE TRIGGER IT.TA_IG_UNI_NEG_METAS
  AFTER DELETE OR UPDATE
     ON IG_UNI_NEG_METAS
    FOR EACH ROW
declare
v_tipo ig_par_conceptos.tip_meta%type;
BEGIN
  --RECALCULAR METAS SI SE MODIFICA   
  if updating then
    --si se modifican los montos, se deben recalcular los hijos
     if :new.mto_meta <> :old.mto_meta then
        --actualiza metas en oficiales
        update ig_ofi_metas
           set mto_meta =  :new.mto_meta * (por_meta / 100)
         where cod_concepto = :new.cod_concepto
           and nvl(cod_sub_concepto,-1) = nvl(:new.cod_sub_concepto,-1) 
           and cod_periodo = :new.cod_periodo
           and cod_unidad = :new.cod_unidad;
     end if;
  end if;
EXCEPTION
  when others then
    raise_application_error(-20000,'Act.Metas en Oficiales. '||sqlerrm);
END;
/

