namespace data_sync.API.DTOs;

public class ConfirmUploadResponseDto
{
    public int SuccessCount { get; set; }
    public int ErrorCount { get; set; }
    public List<ValidationErrorDto> Errors { get; set; } = new();
}

public class ValidationErrorDto
{
    public string FileName { get; set; } = string.Empty;
    public string ErrorMessage { get; set; } = string.Empty;
}