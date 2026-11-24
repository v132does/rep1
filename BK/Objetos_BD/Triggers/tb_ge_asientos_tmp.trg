CREATE OR REPLACE TRIGGER IT.TB_GE_ASIENTOS_TMP
 BEFORE INSERT
 ON GE_ASIENTOS_TMP
 FOR EACH ROW

BEGIN
   if :new.mto_equ_local < 0 and :new.tip_mov_rubro in ('D','C') then 
      :new.monto := :new.monto * -1;
      :new.mto_equ_local := :new.mto_equ_local * -1;
      if :new.tip_mov_rubro = 'D' then
         :new.tip_mov_rubro := 'C';
      elsif :new.tip_mov_rubro = 'C' then   
         :new.tip_mov_rubro := 'D'; 
      end if;    
   end if;   
END;
/

