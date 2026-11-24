CREATE OR REPLACE TRIGGER IT.TB_GE_CUENTAS
 BEFORE DELETE OR INSERT OR UPDATE
 ON GE_CUENTAS
 FOR EACH ROW

DECLARE

V_ESTADO VARCHAR2(1);
V_CAT_CTA_DOCUMENTAR GE_PAR_DINAMICOS.VAL_PARAMETRO%TYPE := 'N'; 
V_FAT_CTA_AFECTADAS  GE_PAR_DINAMICOS.VAL_PARAMETRO%TYPE := 'N';
BEGIN
  if inserting or updating then
     --- Validar que no se grabe numeros de cuentas en 999999999999999
     if :new.nro_cuenta = '999999999999999' then
        raise_application_error(-20000,'Número de cuenta no permitido');
     end if;
  end if;
  If updating then
    If nvl(:new.est_verificacion,'X') <> nvl(:old.est_verificacion,'X') then
      If :new.est_verificacion is null then
        raise_application_error(-20000,'El estado no puede ser nulo');
      End if;
      if :new.est_verificacion = 'V' then
         :new.fec_verificacion := pag_cal.FU_OBT_FEC_ACTUAL(pae_cnf.G_COD_MODULO);
         :new.cod_usu_verificador := user;
      end if;
    End if;
  End if;

  ---*  VERIFICA SI LA OFICINA ESTA ACTIVA ANTES DE INSERTAR LA CTA
     if inserting or updating then
      begin
       select estado into v_estado
         from ba_oficinas
        where cod_oficina = :new.cod_oficina;
      exception
        WHEN NO_DATA_FOUND THEN
           raise_application_error(-20001,'No encontro oficina :'||SQLERRM);
        WHEN TOO_MANY_ROWS THEN
           raise_application_error(-20001,'Varias Oficinas con ese nro.'||SQLERRM);
        when others then
           raise_application_error(-20002,'Otro error :'||SQLERRM);
      end;
       if NVL(v_estado,'A') = 'I' then
          raise_application_error(-20001,'Oficina Inactiva');
       end if;
       --Verificar si está deshabilitado para apertura de cuentas--
       if nvl(:new.cod_oficina,0) <> nvl(:old.cod_oficina,0) then
         if nvl(fug_obt_pardinamico('COD_OFI_DES_APE_CUENTAS', nvl(:new.cod_modulo,null), null, null, :new.cod_oficina),'N') = 'S' then
            raise_application_error(-20001,'Oficina '||:new.cod_oficina||' no habilitada para Apertura de Cuentas');
         end if;
       end if;
     end if;
  ---*
     --CATASTRO CROOC-6 - 17/06/2014 
     If inserting or updating then
        V_CAT_CTA_DOCUMENTAR := fug_obt_pardinamico('CAT_CTA_DOCUMENTAR',:new.cod_modulo,:new.cod_modalidad);
        If :new.estado = 'A' and V_CAT_CTA_DOCUMENTAR = 'S' and nvl(pae_cnf.G_PROGRAMA,'X') in ('GMVERCTA')   then
          prg_ins_doc_catastro (FUG_OBT_CLI_PRINCIPAL(:new.nro_cuenta),:new.nro_cuenta);
        End if;  
     End If;
    
     ---FATCA CROFATCA-38 - LCABRERA: 28/10/2014
   If nvl(pae_cnf.G_PROGRAMA,'X')  in ('GMVERCTA') then
     If inserting or updating then
         if :new.cod_modulo != 5 then ---Se excluyen las tarjetas de Crédito
           V_FAT_CTA_AFECTADAS := fug_obt_pardinamico('FAT_CTA_AFECTADAS',:new.cod_modulo,:new.cod_modalidad);
            If :new.estado = 'A'  and nvl(V_FAT_CTA_AFECTADAS,'N') = 'S' then
              PAE_FAT.PR_ACT_EST_ALT_CUENTA(:new.nro_cuenta);
            End if; 
         end if; 
       End If;  
    End If;   
     
END;
/

