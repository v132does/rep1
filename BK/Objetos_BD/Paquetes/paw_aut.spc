CREATE OR REPLACE PACKAGE IT.paw_aut IS

  PROCEDURE pr_autorizarOperacion(p_sesion               IN VARCHAR2,
                                  p_codigoCanal          IN VARCHAR2,
                                  p_modo                 IN VARCHAR2,
                                  p_numeroDocumento      IN NUMBER,
                                  p_comentario           IN VARCHAR2,
                                  p_claveTransaccional   IN VARCHAR2,
                                  p_error                OUT VARCHAR2,
                                  p_nombreRespuesta      OUT VARCHAR2,
                                  p_descripcionRespuesta OUT VARCHAR2,
                                  p_numeroDoc            OUT NUMBER);
END paw_aut;
/
