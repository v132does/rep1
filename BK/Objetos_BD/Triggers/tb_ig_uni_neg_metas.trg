CREATE OR REPLACE TRIGGER IT.TB_IG_UNI_NEG_METAS
 BEFORE DELETE OR INSERT OR UPDATE
 ON IG_UNI_NEG_METAS
 FOR EACH ROW
declare
v_tipo ig_par_conceptos.tip_meta%type;  
BEGIN
   if deleting or updating then
      if :old.liquidado = 'S' then
         raise_application_error(-20000,'No puede actualizar o eliminar registros liquidados');
      end if;
   end if;
   if updating then
      if :new.por_meta <> :old.por_meta then -- si modifica % calcular monto
         --recuperar tipo de meta
         v_tipo := pai_sgt.fu_obt_tip_meta(:new.cod_periodo,:new.cod_concepto,:new.cod_sub_concepto);
         if nvl(v_tipo,'x') <> 'P' then --actualizar montos 
            --recuperar monto de la meta para calcular
            :new.mto_meta := fui_obt_mto_meta(:new.cod_periodo,:new.cod_concepto,:new.cod_sub_concepto) * (:new.por_meta / 100);
         else
            :new.mto_meta := :new.por_meta;
         end if;
      end if;
   end if;

END;
/

