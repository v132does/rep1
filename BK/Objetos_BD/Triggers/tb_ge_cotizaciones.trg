CREATE OR REPLACE TRIGGER IT.tb_ge_cotizaciones
 BEFORE DELETE OR INSERT OR UPDATE
 ON "IT"."GE_COTIZACIONES"
 FOR EACH ROW

DECLARE
 v_date             date;     
 v_bidPrice         number(19,4);
 v_askPrice         number(19,4);
 v_tipo             varchar2(1) default null;

begin
  v_date             := :new.fecha;
  v_bidprice         := :new.val_com_autorizador;
  v_askprice         := :new.val_ven_autorizador;
  -- si existe alta o actualizacion de los campos val_ven_autorizador, val_com_autorizador
  -- se invoca al web service para dar de alta/actualizacion en global processing
   v_tipo := 'X';
   if inserting then
      if :new.val_com_autorizador is not null and :new.val_ven_autorizador is not null and
         :old.val_com_autorizador is null and :old.val_ven_autorizador is null
         and pag_gen.fu_obt_mon_fuerte = :new.cod_moneda then
           v_tipo := 'A'; -- alta
      end if;
   elsif updating then
      if :new.val_com_autorizador is not null and :new.val_ven_autorizador is not null and
         (:new.val_com_autorizador != nvl(:old.val_com_autorizador,0) or 
         :new.val_ven_autorizador != nvl(:old.val_ven_autorizador,0)) and 
         pag_gen.fu_obt_mon_fuerte = :new.cod_moneda then

         if nvl(:old.val_com_autorizador,0) = 0 then
           v_tipo := 'A'; -- alta
         else
           v_tipo := 'M'; -- modificacion
         end if;
      end if;
   end if;
   if v_tipo != 'X' then
     /**
      ** inserta/actualiza la cotizacion en global
      **/
     prg_glp_cotizacion('T',
                        v_tipo,
                        v_date,
                        v_bidPrice,
                        v_askPrice); 
   end if;
end;
/

