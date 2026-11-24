CREATE OR REPLACE TRIGGER IT.TA_IG_ENT_METAS
  AFTER DELETE OR UPDATE
     ON IG_ENT_METAS
    FOR EACH ROW
declare
v_tipo ig_par_conceptos.tip_meta%type;
BEGIN
  --RECALCULAR METAS SI SE MODIFICA   
  if updating then
     if :new.meta <> :old.meta then
        --recuperar tipo de meta
        v_tipo := pai_sgt.FU_OBT_TIP_META(:new.COD_PERIODO,:new.COD_CONCEPTo,:new.COD_SUB_CONCEPTO);
        if nvl(v_tipo,'x') <> 'P' then --actualiza montos
          --actualiza metas en unidades de negocios
          update ig_uni_neg_metas
             set mto_meta =  :new.meta * (por_meta / 100)
           where cod_concepto = :new.cod_concepto
             and nvl(cod_sub_concepto,-1) = nvl(:new.cod_sub_concepto,-1) 
             and cod_periodo = :new.cod_periodo;
        else --actualiza porcentajes
          --actualiza metas en unidades de negocios
          update ig_uni_neg_metas
             set por_meta = :new.meta --x triger se modifica el monto
           where cod_concepto = :new.cod_concepto
             and nvl(cod_sub_concepto,-1) = nvl(:new.cod_sub_concepto,-1) 
             and cod_periodo = :new.cod_periodo
             and por_meta = :old.meta; --sólo si el porcentaje era el mismo 
        end if;
     end if;
  end if;
EXCEPTION
  when others then
    raise_application_error(-20000,'Act.Metas en Unidades. '||sqlerrm);
END;
/

