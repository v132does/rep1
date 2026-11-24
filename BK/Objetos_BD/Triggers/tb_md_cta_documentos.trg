CREATE OR REPLACE TRIGGER IT.TB_MD_CTA_DOCUMENTOS
 BEFORE DELETE OR INSERT OR UPDATE
 ON MD_CTA_DOCUMENTOS
 FOR EACH ROW

Begin
  
  If inserting Then
    :new.fec_cam_estado := pag_cal.fu_obt_fec_actual(10);
    
    -- REQUERIMIENTO REPO - CNFREINT-1 - RBARRIOS - 10-2015 - CNFREINT-104
    If FUM_OBT_OPE_REPO(:new.cod_modulo,:new.cod_modalidad,'S','R') = 'N' or 
       FUM_OBT_OPE_REPO(:new.cod_modulo,:new.cod_modalidad,'S','O') = 'N' Then --CNFREINT-104 - RABP - 05-2016
        :new.sal_disponible := :new.monto;
    end if;

    begin
      insert into md_cuo_instrumentos (nro_cuenta, nro_cuota, mto_cuota, estado)  
           values (:new.nro_cuenta, 1, :new.monto, :new.estado);
    exception
      when DUP_VAL_ON_INDEX then
        raise_application_error(-20001,'cuo '||:new.nro_cuenta||'-'||sqlerrm);
      when others then
        raise_application_error(-20001, 'Al intentar insertar Cuota - Cta.: '||:new.nro_cuenta||'-'||sqlerrm);
     end;
    
  Elsif updating Then 
    If :new.estado <> :old.estado then
      :new.fec_cam_estado := pag_cal.fu_obt_fec_actual(10);
      
      -- REQUERIMIENTO REPO - CNFREINT-1 - RBARRIOS - 10-2015
      If (FUM_OBT_OPE_REPO(:old.cod_modulo,:old.cod_modalidad,'S','R') = 'N' or FUM_OBT_OPE_REPO(:old.cod_modulo,:old.cod_modalidad,'S','O') = 'N') 
			   And :old.Sal_Disponible = :new.Sal_Disponible Then	--CNFREINT-104 - RABP - 05-2016
           Update md_cuo_instrumentos c
              Set c.estado = :new.estado
            Where c.nro_cuenta = :old.nro_cuenta
              And c.nro_cuota = 1;
      End If;      
      
    End if;      
  End if;
  
end;
/

