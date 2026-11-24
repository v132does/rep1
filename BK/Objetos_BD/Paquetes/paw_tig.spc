CREATE OR REPLACE PACKAGE IT.paw_tig IS

  v_nro_terminal     varchar2(3);
  v_cod_operacion    varchar2(3);
  v_cod_aprobado     varchar2(03) := '000';
  v_mon_dec_invalida varchar2(03) := '-87';
  v_max_imp_archivo  number := 1800;
  v_tra_spi          varchar2(1) := 'N';
  v_tra_spi_ind      varchar2(1) := 'N';
  v_patrocinador     varchar2(1) := 'N';
  v_alias            varchar2(50);
  v_mod_estado       ba_modulos.estado%TYPE;
  C_COD_HOMEBANKING  CONSTANT VARCHAR2(5) := '999';
  C_COD_USSD         CONSTANT VARCHAR2(5) := '993';

  TYPE typ_respuestaLimite IS RECORD(
    error                VARCHAR(1),
    nombreRespuesta      VARCHAR2(15),
    descripcionRespuesta VARCHAR2(200),
    codRespuesta         VARCHAR2(2));

  FUNCTION fu_validarSesion(p_sesionUsuario IN VARCHAR2,
                            p_codCanal      IN VARCHAR2,
                            p_validar       IN VARCHAR DEFAULT 'S')
    RETURN typ_validarSesion;

  PROCEDURE pr_tigo_cash_in(p_sesion               IN VARCHAR2,
                            p_codCanal             IN VARCHAR2,
                            p_nroCtaDebito         IN VARCHAR2,
                            p_monto                IN NUMBER,
                            p_nrotelefono          IN VARCHAR2,
                            p_modo                 IN VARCHAR2,
                            p_nro_mov_pendiente    IN bw_mov_pendientes.nro_documento%type default null,
                            p_error                out VARCHAR2,
                            p_nombreRespuesta      out VARCHAR2,
                            p_descripcionRespuesta out VARCHAR2,
                            p_tipOperacion         out VARCHAR2,
                            p_nroDocumento         out NUMBER);

  PROCEDURE pr_tigo_cash_out(p_sesion               IN VARCHAR2,
                             p_codCanal             IN VARCHAR2,
                             p_nroCtaDebito         IN VARCHAR2,
                             p_monto                IN NUMBER,
                             p_nrotelefono          IN VARCHAR2,
                             p_modo                 IN VARCHAR2,
                             p_nro_mov_pendiente    IN bw_mov_pendientes.nro_documento%type default null,
                             p_error                out VARCHAR2,
                             p_nombreRespuesta      out VARCHAR2,
                             p_descripcionRespuesta out VARCHAR2,
                             p_tipOperacion         out VARCHAR2,
                             p_nroDocumento         out NUMBER);

  PROCEDURE pr_tigo_comp_min(p_sesion               IN VARCHAR2,
                             p_codCanal             IN VARCHAR2,
                             p_nroCtaDebito         IN VARCHAR2,
                             p_monto                IN NUMBER,
                             p_nrotelefono          IN VARCHAR2,
                             p_modo                 IN VARCHAR2,
                             p_nro_mov_pendiente    IN bw_mov_pendientes.nro_documento%type default null,
                             p_error                out VARCHAR2,
                             p_nombreRespuesta      out VARCHAR2,
                             p_descripcionRespuesta out VARCHAR2,
                             p_tipOperacion         out VARCHAR2,
                             p_nroDocumento         out NUMBER);

  PROCEDURE pr_autorizarOperacion(p_sesion               IN VARCHAR2,
                                  p_codigoCanal          IN VARCHAR2,
                                  p_modo                 IN VARCHAR2,
                                  p_numeroDocumento      IN NUMBER,
                                  p_comentario           IN VARCHAR2,
                                  p_error                out VARCHAR2,
                                  p_nombreRespuesta      out VARCHAR2,
                                  p_descripcionRespuesta out VARCHAR2);

  PROCEDURE pr_tigo_cash_in_724(p_nroCtaDebito         IN VARCHAR2,
                                p_monto                IN NUMBER,
                                p_tipOperacion         IN VARCHAR2,
                                p_nroPedido            IN VARCHAR2,
                                p_nroComprobante       out VARCHAR2,
                                p_fechaProceso         out date,
                                p_fechaOperacion       out date,
                                p_horaOperacion        out VARCHAR2,
                                p_error                out VARCHAR2,
                                p_nombreRespuesta      out VARCHAR2,
                                p_descripcionRespuesta out VARCHAR2);

  PROCEDURE pr_tigo_cash_out_724(p_nroCtaDebito         IN VARCHAR2,
                                 p_monto                IN NUMBER,
                                 p_tipOperacion         IN VARCHAR2,
                                 p_nroPedido            IN VARCHAR2,
                                 p_nroComprobante       out VARCHAR2,
                                 p_fechaProceso         out date,
                                 p_fechaOperacion       out date,
                                 p_horaOperacion        out VARCHAR2,
                                 p_error                out VARCHAR2,
                                 p_nombreRespuesta      out VARCHAR2,
                                 p_descripcionRespuesta out VARCHAR2);

  procedure pr_gen_rev_operacion(p_tipOperacion         in varchar2,
                                 p_mov_id               in varchar2,
                                 p_error                out VARCHAR2,
                                 p_nombreRespuesta      out VARCHAR2,
                                 p_descripcionRespuesta out VARCHAR2);
END paw_tig;
/
