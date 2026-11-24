create or replace PACKAGE it.PAW_ALI IS

 FUNCTION fu_sol_per_alias    (p_cod_persona      in varchar2,
                               p_modo             in varchar2  default 'A',
                               p_tip_ide_cli      in VARCHAR2,
                               p_val_ide_cli      in VARCHAR2,
                               p_tip_ide_alias    in VARCHAR2,
                               p_val_ide_alias    in VARCHAR2,
                               p_nro_cuenta       in VARCHAR2,
                               p_cta_defecto      in VARCHAR2,
                               p_tip_accion       in VARCHAR2) 
                        RETURN typ_solicitudaltacas;
                        
 FUNCTION fu_eliminar_alias(p_cod_persona      in varchar2,
                           p_modo          in varchar2 default 'A',
                           p_ali_record_id in varchar2,
                           p_cta_record_id in varchar2,
                           p_accion        in varchar2 default 'ELI') 
                        RETURN typ_solicitudaltacas;
                        
  FUNCTION fu_Soli_edicion_alias(p_cli_recorid in varchar2,
                              p_cta_recorid in varchar2,
                              p_ali_recorid in varchar2,
                              p_accion      in varchar2) 
                        RETURN typ_solicitudPagoSpi ;    
                        
  FUNCTION fu_sol_con_persona(p_cod_persona      in varchar2,
                              p_tip_consulta  IN VARCHAR2,
                              p_tip_identificador IN VARCHAR2,
                              p_val_identificador IN VARCHAR2) 
                         RETURN typ_sol_con_cas;   
                         
  FUNCTION fu_res_con_persona(p_cod_persona    IN VARCHAR2,
                              p_nro_referencia IN VARCHAR2)
                         RETURN typ_res_con_cas;
                         
  FUNCTION fu_obt_lis_alias_spi (p_cod_persona IN VARCHAR2) 
  RETURN typ_lisaliasspi;                         

  FUNCTION fu_obtenerDetalleCuentas(p_cod_persona IN VARCHAR2, 
                                    p_nroCuentaEspecifica IN VARCHAR2 DEFAULT NULL) 
  RETURN typ_obtenerDetalleCuentas;
  
  FUNCTION fu_datoCliente( p_codPersona        IN VARCHAR2,
                            p_direccion         IN VARCHAR2 DEFAULT NULL,--No debe ser nulo para p_tipoSolicitud = B. Debe tener mayor a 10 caracteres
                            p_codCiudad         IN VARCHAR2 DEFAULT NULL,--No debe ser nulo para p_tipoSolicitud = B.
                            p_codBarrio         IN VARCHAR2 DEFAULT NULL,--No debe ser nulo para p_tipoSolicitud = B.
                            p_codNumero         IN VARCHAR2 DEFAULT NULL,--numero de casa
                            p_codEdificio       IN VARCHAR2 DEFAULT NULL,
                            p_codPiso           IN VARCHAR2 DEFAULT NULL,
                            p_codDepartamento   IN VARCHAR2 DEFAULT NULL,
                            p_codigoArea        IN VARCHAR2 DEFAULT NULL,
                            p_telefono          IN VARCHAR2 DEFAULT NULL,
                            p_email             IN VARCHAR2 DEFAULT NULL,
                            p_modo              IN VARCHAR2, --Modos-> D: Consulta Detalles, V: Verificar, C: Confirmar
                            p_tipoSolicitud     IN VARCHAR2 DEFAULT NULL--Solo puede ser nulo en el Modo D. A : Direccion, T: Telefono, E; Email, C: Celular, EC: Email Confirmado, CC: Celular Confirmado ATM, CR: Celular Rechazado ATM
                            )
  RETURN typ_datosCliente;  
  
END PAW_ALI;