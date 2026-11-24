CREATE OR REPLACE TRIGGER IT.TA_MD_CUO_INSTRUMENTOS
 AFTER DELETE OR INSERT OR UPDATE
 ON MD_CUO_INSTRUMENTOS
 FOR EACH Row  
begin
  If  updating Then
    If :new.estado <> :old.estado Then          
      If :new.estado = 'R' And :old.nro_cta_repo is Not Null Then
         begin
           update md_cta_documentos d
               set d.sal_disponible = Nvl(d.sal_disponible,0) - Nvl(:old.mto_cuota,0)
             where d.nro_cuenta = :old.nro_cuenta;
         exception
           when others then
             RAISE_APPLICATION_ERROR( -20000, 'Error al intentar Restar sal_disponible en MD_CTA_DOCUMENTOS. Nro. Cta.:'||:old.nro_cuenta||sqlerrm );
         end;
      End If;
      If :new.estado = 'N' And :old.nro_cta_repo is Not Null Then
         begin
           update md_cta_documentos d
               set d.sal_disponible = Nvl(d.sal_disponible,0) + Nvl(:Old.mto_cuota,0)
             where d.nro_cuenta = :old.nro_cuenta;
         exception
           when others then
             RAISE_APPLICATION_ERROR( -20000, 'Error al intentar Sumar sal_disponible en MD_CTA_DOCUMENTOS. Nro. Cta.:'||:old.nro_cuenta||sqlerrm );
         end;
      End If;
    End if;
  End if;
end;
/

